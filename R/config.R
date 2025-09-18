# Finds a repo-local config file if available; else returns defaults.
todo_config <- function(repo_dir = getOption("todoengine.repo", getwd())) {
  cfg_path <- file.path(repo_dir, "todoengine_config.R")
  if (file.exists(cfg_path)) {
    env <- new.env(parent = emptyenv())
    sys.source(cfg_path, envir = env)
    if (is.function(env$todo_config_local)) {
      cfg <- env$todo_config_local()
      return(cfg)
    }
  }
  # Defaults if no local config
  list(
    tz = "America/Chicago",
    indent = 2L,
    live_dir    = file.path(repo_dir, "this_week"),
    archive_dir = file.path(repo_dir, "archive"),
    filename_fmt = "ToDo_%y%m%d_%s.txt",
    daily_sections = c("Monday","Tuesday","Wednesday","Thursday","Friday"),
    render_markdown = TRUE,
    render_html = TRUE
  )
}

# Convenience: remember a repo path for this R session.
#' @export
use_repo <- function(repo_dir) {
  repo_dir <- normalizePath(path.expand(repo_dir), mustWork = TRUE)
  options(todoengine.repo = repo_dir)
  invisible(repo_dir)
}
