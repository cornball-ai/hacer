.monday_of <- function(d) {
  w <- as.POSIXlt(d)$wday; w[w==0] <- 7L
  as.Date(d) - (w - 1L)
}

.period_types <- c("Daily","Month","Quarter","Week")  # capitalized internal names

.build_names_for <- function(date) {
  ds <- format(date, "%y%m%d")
  paste0("todo_", ds, "_", tolower(.period_types), ".md")
}

# Resolve actual on-disk paths for a given Monday's period files. Prefers the
# canonical .md form, falls back to legacy lowercase .txt then capitalized
# ToDo_*.txt — old repos keep working. Returns the .md canonical path when
# nothing is on disk yet (the path that would be written next).
.resolve_period_paths <- function(date, dir) {
  ds <- format(date, "%y%m%d")
  out <- character(length(.period_types))
  for (i in seq_along(.period_types)) {
    p <- .period_types[i]
    md      <- file.path(dir, paste0("todo_", ds, "_", tolower(p), ".md"))
    txt_lo  <- file.path(dir, paste0("todo_", ds, "_", tolower(p), ".txt"))
    txt_up  <- file.path(dir, paste0("ToDo_", ds, "_", p, ".txt"))
    out[i] <- if (file.exists(md))     md
              else if (file.exists(txt_lo)) txt_lo
              else if (file.exists(txt_up)) txt_up
              else md
  }
  out
}

#' File paths for a given week's ToDo files
#'
#' Returns the canonical lowercase filenames. Pre-0.1.7 repos that still
#' have capitalized `ToDo_*.txt` files are still recognized by readers; new
#' writes always emit lowercase.
#'
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @export
paths_for <- function(date = Sys.Date(), cfg = todo_config()) {
  files <- .build_names_for(.monday_of(date))
  live  <- file.path(cfg$live_dir,  files)
  arch  <- file.path(cfg$archive_dir, files)
  list(files = files, live = live, archive = arch)
}
