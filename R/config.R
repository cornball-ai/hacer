# Resolves the ToDo repo path:
#   arg > options("hacer.repo") > Sys.getenv("HACER_REPO") > R_user_dir("hacer", "data")
.default_repo_dir <- function() {
  opt <- getOption("hacer.repo", NULL)
  if (!is.null(opt)) return(opt)
  env <- Sys.getenv("HACER_REPO", unset = "")
  if (nzchar(env)) env else tools::R_user_dir("hacer", "data")
}

#' Load the ToDo repo configuration
#'
#' Resolution order for `repo_dir`:
#' 1. The argument if supplied.
#' 2. `options("hacer.repo")` (set by `use_repo()` within a session).
#' 3. The `HACER_REPO` environment variable (for one-shot CLI invocations
#'    like `HACER_REPO=~/todo r -e 'hacer::run_monday()'`).
#' 4. `tools::R_user_dir("hacer", "data")` (CRAN-safe fallback; ugly path,
#'    so users typically instantiate at `~/todo` and set the option or env
#'    var instead).
#'
#' @param repo_dir Path to your ToDo repo directory.
#' @importFrom yaml read_yaml
#' @export
todo_config <- function(repo_dir = .default_repo_dir()) {
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
      filename_fmt = "todo_%y%m%d_%s.md",
      daily_sections = c("Monday","Tuesday","Wednesday","Thursday","Friday"),
      render_html = TRUE
    )
  }
}

#' Path to the live todo file
#'
#' The single-file workflow keeps one hand-edited `todo.md` in `live_dir`.
#' [snapshot()] copies it to a dated file each day and [survey()] reads it.
#'
#' @param cfg A config list from `todo_config()`.
#' @return The path `<live_dir>/todo.md`. The file need not exist.
#' @export
todo_file <- function(cfg = todo_config()) {
  file.path(cfg$live_dir, "todo.md")
}

# survey() settings: option > env var > NULL. Nothing user-specific lives in
# the package; set these in ~/.Rprofile or on the command line.
.survey_owners <- function() {
  opt <- getOption("hacer.survey_owners", NULL)
  if (!is.null(opt)) return(opt)
  env <- Sys.getenv("HACER_SURVEY_OWNERS", unset = "")
  if (nzchar(env)) trimws(strsplit(env, ",", fixed = TRUE)[[1]]) else NULL
}

.tasks_dir <- function() {
  opt <- getOption("hacer.tasks_dir", NULL)
  if (!is.null(opt)) return(opt)
  env <- Sys.getenv("HACER_TASKS_DIR", unset = "")
  if (nzchar(env)) env else NULL
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
