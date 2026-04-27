# R/migrate.R

#' Migrate legacy .txt todo files to markdown .md
#'
#' Walks `cfg$live_dir` for `.txt` files matching the `todo_*` pattern,
#' reads each via the dual-format parser, writes a `.md` companion in the
#' new markdown task-list syntax (`- [X] text`), and removes the `.txt`
#' source after a successful write.
#'
#' Surfaces a warning listing any tasks that carried the legacy `*`
#' recurring marker — the new writer drops `*` entirely, so add those
#' paths to `recurring.txt` if you want them to keep recurring.
#'
#' Archive files are not touched. If you want them migrated, do it
#' manually with `git mv` + a script — or wait until the question matters
#' enough to dial the defaults in.
#'
#' @param cfg Config from [todo_config()].
#' @param preview If `TRUE`, return a `hacer_preview` without writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#'
#' @export
migrate_to_markdown <- function(cfg = todo_config(),
                                preview = .preview_default()) {
  txts <- list.files(cfg$live_dir,
                     pattern = "^todo_\\d{6}_.+\\.txt$",
                     full.names = TRUE,
                     ignore.case = TRUE)

  if (!length(txts)) {
    message("No legacy .txt files in ", cfg$live_dir, ". Nothing to migrate.")
    if (preview) return(.new_preview())
    return(invisible(character()))
  }

  targets <- list()
  removed <- character()
  recur_tasks <- list()

  for (txt in txts) {
    md_path <- sub("\\.txt$", ".md", txt)
    period <- infer_period_from_filename(txt)
    period_eff <- if (is.na(period)) "Daily" else period
    df <- parse_todo(txt, period_eff, indent = cfg$indent %||% 2L)

    if (any(isTRUE_vec(df$recur))) {
      recur_paths <- unique(df$path[isTRUE_vec(df$recur)])
      recur_tasks[[basename(txt)]] <- recur_paths
    }

    new_lines <- build_todo_txt_lines(df, md_path, period_eff, cfg)
    targets[[md_path]] <- new_lines
    removed <- c(removed, txt)
  }

  result <- .write_or_preview(targets, preview)

  if (preview) {
    if (length(removed)) {
      message("Migrate preview: would also remove ", length(removed),
              " legacy .txt file(s):")
      for (r in removed) message("  - ", r)
    }
  } else {
    file.remove(removed)
    message("Migrated ", length(targets), " file(s) to markdown.")
  }

  if (length(recur_tasks)) {
    message("")
    message("Tasks with legacy `*` recurring marker (the marker is no",
            " longer written;\nadd these paths to recurring.txt if",
            " you want them to keep recurring):")
    for (file in names(recur_tasks)) {
      message("  ", file, ":")
      for (path in recur_tasks[[file]]) {
        message("    ", path)
      }
    }
  }

  if (preview) return(result)
  invisible(names(targets))
}

`%||%` <- function(a, b) if (is.null(a)) b else a
