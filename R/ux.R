#' Open this week's files for quick editing
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @export
open_this_week <- function(date = Sys.Date(), cfg = todo_config()) {
  p <- paths_for(date, cfg)$live
  p <- p[file.exists(p)]
  if (!length(p)) stop("No live files found.")
  for (f in p) try(utils::file.edit(f), silent = TRUE)
  invisible(p)
}

#' Quick check that repo is wired correctly
#' @param repo_dir Path to your ToDo repo directory.
#' @export
check_setup <- function(repo_dir = getOption("hacer.repo", getwd())) {
  cfg <- todo_config(repo_dir)
  ok <- dir.exists(cfg$live_dir) && dir.exists(cfg$archive_dir)
  list(config = cfg, ok = ok)
}
