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
#' @export
roll_day <- function(date = Sys.Date(), cfg = todo_config()) {
  dir.create(cfg$live_dir, recursive = TRUE, showWarnings = FALSE)

  types <- c("Daily", "Week", "Month", "Quarter")
  live_files <- list.files(cfg$live_dir, pattern = "^ToDo_\\d{6}_.+\\.txt$")

  if (!length(live_files)) {
    message("No prior files found in ", cfg$live_dir, ". Nothing to roll.")
    return(invisible(character()))
  }

  m <- regmatches(live_files, regexec(
    "^ToDo_(\\d{6})_(Daily|Week|Month|Quarter)\\.txt$", live_files))
  valid <- vapply(m, length, integer(1L)) == 3L
  if (!any(valid)) {
    message("No valid ToDo files found in ", cfg$live_dir, ". Nothing to roll.")
    return(invisible(character()))
  }

  m <- m[valid]
  file_dates <- as.Date(vapply(m, `[`, character(1L), 2L), format = "%y%m%d")
  file_types <- vapply(m, `[`, character(1L), 3L)

  today_str <- format(date, "%y%m%d")
  created <- character()
  done_log <- character()

  repo_dir <- dirname(cfg$live_dir)
  done_log_path <- file.path(repo_dir, "done.log")

  for (tp in types) {
    idx <- which(file_types == tp)
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
    dst_name <- paste0("ToDo_", today_str, "_", tp, ".txt")
    dst_file <- file.path(cfg$live_dir, dst_name)

    lines <- readLines(src_file, warn = FALSE)
    out_lines <- character()

    for (ln in lines) {
      stripped <- sub("^\\s+", "", ln)
      if (!grepl("^\\[( |/|x|!)\\]\\s*-", stripped)) {
        out_lines <- c(out_lines, ln)
        next
      }

      status <- substr(stripped, 2L, 2L)
      rest <- sub("^\\[( |/|x|!)\\]\\s*-\\s*", "", stripped)
      recur <- grepl("^\\*", rest)

      if (status == "x" && !recur) {
        indent <- sub("^(\\s*).*", "\\1", ln)
        task_text <- sub("^\\s*\\[( |/|x|!)\\]\\s*-\\s*", "", ln)
        done_log <- c(
          done_log,
          paste0(format(date, "%Y-%m-%d"), "  ", indent, task_text))
        next
      }

      if (status == "x" && recur) {
        ln <- sub("[x]", "[ ]", ln, fixed = TRUE)
      }

      out_lines <- c(out_lines, ln)
    }

    writeLines(out_lines, dst_file)
    created <- c(created, dst_file)
  }

  if (length(done_log)) {
    if (file.exists(done_log_path)) {
      cat(paste0(done_log, "\n"), file = done_log_path, append = TRUE)
    } else {
      writeLines(done_log, done_log_path)
    }
  }

  if (length(created)) {
    message("Rolled to ", format(date), ": ",
            paste(basename(created), collapse = ", "))
  } else {
    message("Nothing to roll for ", format(date))
  }

  invisible(created)
}
