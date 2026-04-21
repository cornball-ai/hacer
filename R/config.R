#' Load the ToDo repo configuration
#' @param repo_dir Path to your ToDo repo directory.
#' @importFrom yaml read_yaml
#' @export
todo_config <- function(repo_dir = getOption("hacer.repo", getwd())) {
  repo_dir <- path.expand(repo_dir)
  cfg_path <- file.path(repo_dir, "config.yaml")
  
  if (file.exists(cfg_path)) {
    return(yaml::read_yaml(cfg_path))
  } else {
    # defaults if no local file present
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
}

# Convenience: remember a repo path for this R session.
#' Remember a repo path for this R session
#' @param repo_dir Path to your ToDo repo directory.
#' @export
use_repo <- function(repo_dir) {
  repo_dir <- normalizePath(path.expand(repo_dir), mustWork = TRUE)
  options(hacer.repo = repo_dir)
  invisible(repo_dir)
}
