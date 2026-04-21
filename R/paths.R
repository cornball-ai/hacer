.monday_of <- function(d) {
  w <- as.POSIXlt(d)$wday; w[w==0] <- 7L
  as.Date(d) - (w - 1L)
}

.period_types <- c("Daily","Month","Quarter","Week")  # order you prefer

.build_names_for <- function(date) {
  ds <- format(date, "%y%m%d")
  paste0("ToDo_", ds, "_", .period_types, ".txt")
}

#' File paths for a given week's ToDo files
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @export
paths_for <- function(date = Sys.Date(), cfg = todo_config()) {
  files <- .build_names_for(.monday_of(date))
  live  <- file.path(cfg$live_dir,  files)
  arch  <- file.path(cfg$archive_dir, files)
  list(files = files, live = live, archive = arch)
}
