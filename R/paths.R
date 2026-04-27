.monday_of <- function(d) {
  w <- as.POSIXlt(d)$wday; w[w==0] <- 7L
  as.Date(d) - (w - 1L)
}

.period_types <- c("Daily","Month","Quarter","Week")  # capitalized internal names

.build_names_for <- function(date) {
  ds <- format(date, "%y%m%d")
  paste0("todo_", ds, "_", tolower(.period_types), ".txt")
}

# Resolve actual on-disk paths for a given Monday's period files. Falls back
# to the legacy capitalized form if the lowercase form doesn't exist, so old
# repos keep working. Returns the lowercase canonical path when nothing is
# on disk yet (the path that would be written next).
.resolve_period_paths <- function(date, dir) {
  ds <- format(date, "%y%m%d")
  out <- character(length(.period_types))
  for (i in seq_along(.period_types)) {
    p <- .period_types[i]
    lower <- file.path(dir, paste0("todo_", ds, "_", tolower(p), ".txt"))
    upper <- file.path(dir, paste0("ToDo_", ds, "_", p, ".txt"))
    out[i] <- if (file.exists(lower)) lower
              else if (file.exists(upper)) upper
              else lower
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
