#' Open this week's files for quick editing
#' @export
open_this_week <- function(date = Sys.Date(), cfg = todo_config()) {
  p <- paths_for(date, cfg)$live
  p <- p[file.exists(p)]
  if (!length(p)) stop("No live files found.")
  for (f in p) try(utils::file.edit(f), silent = TRUE)
  invisible(p)
}

#' Quick check that repo is wired correctly
#' @export
check_setup <- function(repo_dir = getOption("todoengine.repo", getwd())) {
  cfg <- todo_config(repo_dir)
  ok <- dir.exists(cfg$live_dir) && dir.exists(cfg$archive_dir)
  list(config = cfg, ok = ok)
}
