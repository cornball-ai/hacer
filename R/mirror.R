# R/mirror.R
# Mirror one subtree of a todo file into another, matching by full path.

# Breadcrumb helpers: a path is "A > B > C". Parent strips the last hop,
# leaf is the last hop, level is the number of " > " separators (0 = root).
.path_parent <- function(p) {
  if (!grepl(" > ", p, fixed = TRUE)) {
    return(NA_character_)
  }
  sub("^(.*) > .+$", "\\1", p)
}

.path_leaf <- function(p) {
  sub("^.* > ", "", p)
}

.path_level <- function(p) {
  lengths(regmatches(p, gregexpr(" > ", p, fixed = TRUE)))
}

# Build a single node row matching parse_todo()'s schema.
.mirror_blank_row <- function(template, path, period, status, order) {
  row <- template[1L, , drop = FALSE]
  row$id <- path
  row$parent_id <- .path_parent(path)
  row$period <- period
  row$section <- NA_character_
  row$name <- .path_leaf(path)
  row$recur <- FALSE
  row$status <- status
  row$level <- .path_level(path)
  row$order <- order
  row$path <- path
  row
}

# Ensure every ancestor of target_path exists in the target frame.
.mirror_ensure_ancestors <- function(tgt_df, target_path, period, template) {
  if (!grepl(" > ", target_path, fixed = TRUE)) {
    return(tgt_df)
  }
  parts <- strsplit(target_path, " > ", fixed = TRUE)[[1L]]
  for (k in seq_len(length(parts) - 1L)) {
    anc <- paste(parts[seq_len(k)], collapse = " > ")
    if (!(anc %in% tgt_df$path)) {
      ord <- if (nrow(tgt_df)) max(tgt_df$order) + 1L else 1L
      new <- .mirror_blank_row(template, anc, period, " ", ord)
      tgt_df <- rbind(tgt_df, new[, names(tgt_df), drop = FALSE])
    }
  }
  tgt_df
}

# Insert a row right after its parent's existing subtree, shifting later
# orders down by one. Top-level rows (NA parent) append at the end.
.mirror_insert <- function(tgt_df, row) {
  pid <- row$parent_id
  if (is.na(pid)) {
    row$order <- if (nrow(tgt_df)) max(tgt_df$order) + 1L else 1L
    return(rbind(tgt_df, row[, names(tgt_df), drop = FALSE]))
  }
  desc <- tgt_df$path == pid | startsWith(tgt_df$path, paste0(pid, " > "))
  parent_order_max <- max(tgt_df$order[desc])
  shift <- tgt_df$order > parent_order_max
  tgt_df$order[shift] <- tgt_df$order[shift] + 1L
  row$order <- parent_order_max + 1L
  rbind(tgt_df, row[, names(tgt_df), drop = FALSE])
}

#' Mirror a subtree from one todo file into another
#'
#' Copies the \code{source_path} subtree of \code{source_file} into the
#' \code{target_path} location of \code{target_file}, matching items by
#' their full \code{"A > B > C"} breadcrumb. The merge is additive:
#' \itemize{
#'   \item paths in the source but not the target are added under the
#'     translated parent (shallow-first, so parents land before children);
#'   \item paths in the target but not the source are kept untouched;
#'   \item shared paths take the source status when
#'     \code{conflict = "source"} (the default) or keep the target status
#'     when \code{conflict = "target"}.
#' }
#' Nothing is ever deleted. Use it to keep a shared planning subtree in
#' step across two repos, e.g. mirror cornelius's
#' \code{"Troy > cornball.ai"} week subtree down into tiny's top-level
#' \code{"cornball.ai"}.
#'
#' @param source_file,target_file Paths to the two todo files.
#' @param source_path,target_path Full breadcrumb of the subtree root in
#'   each file (e.g. \code{"Troy > cornball.ai"} and \code{"cornball.ai"}).
#' @param period Character period label passed to \code{\link{parse_todo}}.
#' @param conflict Which status wins on shared paths: \code{"source"} or
#'   \code{"target"}.
#' @param preview If TRUE, report the planned changes and write nothing.
#' @return Invisibly: \code{target_file} on write, or a list with
#'   \code{added} and \code{restatused} path vectors on preview.
#' @export
mirror_subtree <- function(source_file, target_file,
                           source_path, target_path,
                           period = "Week",
                           conflict = c("source", "target"),
                           preview = .preview_default()) {
  conflict <- match.arg(conflict)
  src_df <- parse_todo(source_file, period)
  tgt_df <- parse_todo(target_file, period)

  in_sub <- src_df$path == source_path |
    startsWith(src_df$path, paste0(source_path, " > "))
  if (!any(in_sub)) {
    message("mirror_subtree: source subtree '", source_path,
            "' is empty; no-op")
    return(invisible(target_file))
  }
  sub <- src_df[in_sub, , drop = FALSE]

  # Translate breadcrumbs from source_path to target_path, then recompute
  # parent/level/leaf from the translated path so nesting depth adapts.
  rel <- substring(sub$path, nchar(source_path) + 1L)
  sub$path <- paste0(target_path, rel)
  sub$parent_id <- vapply(sub$path, .path_parent, character(1),
                          USE.NAMES = FALSE)
  sub$level <- vapply(sub$path, .path_level, integer(1), USE.NAMES = FALSE)
  sub$name <- vapply(sub$path, .path_leaf, character(1), USE.NAMES = FALSE)
  sub$id <- sub$path

  tgt_df <- .mirror_ensure_ancestors(tgt_df, target_path, period, tgt_df)

  restatused <- character()
  shared <- intersect(sub$path, tgt_df$path)
  if (conflict == "source") {
    for (p in shared) {
      old <- tgt_df$status[tgt_df$path == p]
      new <- sub$status[sub$path == p]
      if (!identical(old, new)) {
        tgt_df$status[tgt_df$path == p] <- new
        restatused <- c(restatused, p)
      }
    }
  }

  added <- character()
  missing <- setdiff(sub$path, tgt_df$path)
  if (length(missing)) {
    miss <- sub[sub$path %in% missing, , drop = FALSE]
    miss <- miss[order(nchar(miss$path)), , drop = FALSE]
    for (i in seq_len(nrow(miss))) {
      row <- miss[i, , drop = FALSE]
      if (!is.na(row$parent_id) && !(row$parent_id %in% tgt_df$path)) {
        next
      }
      tgt_df <- .mirror_insert(tgt_df, row)
      added <- c(added, row$path)
    }
  }

  tgt_df <- tgt_df[order(tgt_df$order), , drop = FALSE]
  rownames(tgt_df) <- NULL

  if (isTRUE(preview)) {
    message("mirror_subtree (preview): ", length(added), " added, ",
            length(restatused), " restatused -> ", basename(target_file))
    return(invisible(list(added = added, restatused = restatused)))
  }

  lines <- build_todo_txt_lines(tgt_df, target_file, period)
  writeLines(lines, target_file)
  invisible(target_file)
}
