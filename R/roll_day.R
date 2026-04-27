# R/roll_day.R
#' Roll the most recent ToDo files forward to today
#'
#' Finds the most recent file of each cadence in \code{this_week/}, copies it
#' forward to \code{today}, strips completed non-recurring items, resets
#' recurring done items to blank, and appends dropped items to
#' \code{<repo>/done.log}.
#'
#' @param date A Date. Defaults to \code{Sys.Date()}.
#' @param cfg A config list from \code{todo_config()}.
#' @param preview If \code{TRUE}, return a \code{hacer_preview} describing the
#'   change and write nothing. Defaults to \code{HACER_PREVIEW=1} env var or
#'   \code{FALSE}.
#' @export
roll_day <- function(date = Sys.Date(), cfg = todo_config(),
                     preview = .preview_default()) {
  if (!preview) {
    dir.create(cfg$live_dir, recursive = TRUE, showWarnings = FALSE)
  }

  types <- c("Daily", "Week", "Month", "Quarter")
  live_files <- list.files(cfg$live_dir,
                           pattern = "^todo_\\d{6}_.+\\.(md|txt)$",
                           ignore.case = TRUE)

  if (!length(live_files)) {
    message("No prior files found in ", cfg$live_dir, ". Nothing to roll.")
    if (preview) return(.new_preview())
    return(invisible(character()))
  }

  m <- regmatches(live_files, regexec(
    "^todo_(\\d{6})_(daily|week|month|quarter)\\.(md|txt)$",
    live_files, ignore.case = TRUE))
  valid <- vapply(m, length, integer(1L)) == 4L
  if (!any(valid)) {
    message("No valid ToDo files found in ", cfg$live_dir, ". Nothing to roll.")
    if (preview) return(.new_preview())
    return(invisible(character()))
  }

  m <- m[valid]
  file_dates <- as.Date(vapply(m, `[`, character(1L), 2L), format = "%y%m%d")
  file_types <- vapply(m, `[`, character(1L), 3L)

  today_str <- format(date, "%y%m%d")
  done_log <- character()
  targets <- list()

  repo_dir <- dirname(cfg$live_dir)
  done_log_path <- file.path(repo_dir, "done.log")

  for (tp in types) {
    idx <- which(tolower(file_types) == tolower(tp))
    if (!length(idx)) next

    most_recent <- max(file_dates[idx])
    if (most_recent >= date) {
      message("Most recent ", tp, " (", format(most_recent),
              ") is up to date. Skipping.")
      next
    }

    src_file <- file.path(
      cfg$live_dir,
      live_files[valid][idx][which.max(file_dates[idx])])
    dst_name <- paste0("todo_", today_str, "_", tolower(tp), ".md")
    dst_file <- file.path(cfg$live_dir, dst_name)

    lines <- readLines(src_file, warn = FALSE)
    out_lines <- character()

    for (ln in lines) {
      parsed <- .parse_task_line(ln)
      if (is.null(parsed)) {
        out_lines <- c(out_lines, ln)
        next
      }

      if (parsed$status == "x" && !parsed$recur) {
        indent_lead <- sub("^(\\s*).*", "\\1", ln)
        task_text <- if (grepl("^\\s*-\\s+\\[", ln)) {
          sub("^\\s*-\\s+\\[( |/|x|!)\\]\\s+", "", ln)
        } else {
          sub("^\\s*\\[( |/|x|!)\\]\\s*-\\s*", "", ln)
        }
        done_log <- c(
          done_log,
          paste0(format(date, "%Y-%m-%d"), "  ", indent_lead, task_text))
        next
      }

      if (parsed$status == "x" && parsed$recur) {
        ln <- sub("[x]", "[ ]", ln, fixed = TRUE)
      }

      out_lines <- c(out_lines, ln)
    }

    targets[[dst_file]] <- out_lines
  }

  result <- .write_or_preview(targets, preview, done_log_path, done_log)

  if (!preview) {
    if (length(targets)) {
      message("Rolled to ", format(date), ": ",
              paste(basename(names(targets)), collapse = ", "))
    } else {
      message("Nothing to roll for ", format(date))
    }
    return(invisible(names(targets)))
  }
  result
}
