#' Create a todoengine project layout in a Git repo.
#'
#' @param repo_dir path to your cloned GitHub repo (e.g., "~/Projects/To_Do")
#' @param syncthing_live_dir optional path to a Syncthing folder to use as live_dir
#' @param overwrite whether to overwrite existing config / initial week files
#' @export
instantiate_todo <- function(repo_dir,
                             syncthing_live_dir = NULL,
                             overwrite = FALSE) {
  repo_dir <- normalizePath(path.expand(repo_dir), mustWork = FALSE)
  if (!dir.exists(repo_dir)) dir.create(repo_dir, recursive = TRUE, showWarnings = FALSE)
  
  # sanity: warn if not a git repo (but don’t require)
  has_git <- file.exists(file.path(repo_dir, ".git"))
  
  live_dir <- if (is.null(syncthing_live_dir)) file.path(repo_dir, "this_week")
  else normalizePath(path.expand(syncthing_live_dir), mustWork = FALSE)
  archive_dir <- file.path(repo_dir, "archive")
  
  dir.create(live_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
  
  # 1) write local config file
  cfg_path <- file.path(repo_dir, "todoengine_config.R")
  if (file.exists(cfg_path) && !overwrite) {
    stop("Config already exists at ", cfg_path, ". Set overwrite=TRUE to replace.")
  }
  
  cfg_lines <- c(
    "## Local configuration for todoengine",
    "## You can edit these paths and flags as needed.",
    "todo_config_local <- function() {",
    "  list(",
    "    tz = 'America/Chicago',",
    "    indent = 2L,",
    paste0("    live_dir = '", live_dir, "',"),
    paste0("    archive_dir = '", archive_dir, "',"),
    "    filename_fmt = 'ToDo_%y%m%d_%s.txt',",
    "    daily_sections = c('Monday','Tuesday','Wednesday','Thursday','Friday'),",
    "    render_markdown = TRUE,",
    "    render_html = TRUE",
    "  )",
    "}"
  )
  writeLines(cfg_lines, cfg_path)
  
  # 2) seed initial week in live_dir (based on current Monday)
  mon <- .monday_of(Sys.Date())
  files <- .build_names_for(mon)
  paths <- file.path(live_dir, files)
  
  if (any(file.exists(paths)) && !overwrite) {
    stop("Initial ToDo files already exist in live_dir; set overwrite=TRUE to replace.")
  }
  
  # very small, neutral starters (you can expand later)
  starter_daily <- function(fname) {
    secs <- c("Monday","Tuesday","Wednesday","Thursday","Friday")
    lines <- c(paste0("# ", basename(fname)))
    for (s in secs) {
      lines <- c(lines,
                 "", "#######################################", paste0("\n# ", s), "",
                 "[ ] -*ToDo",
                 "[ ] -*Clean Email",
                 "[ ] -*Exercise",
                 "",
                 "[ ] - House",
                 "  [ ] - Frontyard")
    }
    lines
  }
  
  starter_week <- function(fname) {
    c(paste0("# ", basename(fname)),
      "", "#######################################", "",
      "[ ] -*ToDo",
      "[ ] -*Clean Email",
      "[ ] -*Exercise",
      "",
      "[ ] - House",
      "  [ ] - Second Floor",
      "    [ ] - Fix leaks",
      "      [ ] - Master Window")
  }
  
  starter_month <- function(fname) {
    c(paste0("# ", basename(fname)),
      "", "#######################################", "",
      "[ ] - Projects",
      "  [ ] - Major Task A",
      "  [ ] - Major Task B")
  }
  
  starter_quarter <- function(fname) {
    c(paste0("# ", basename(fname)),
      "", "#######################################", "",
      "[ ] - Quarterly Goals",
      "  [ ] - Theme 1",
      "  [ ] - Theme 2")
  }
  
  starters <- list(starter_daily, starter_month, starter_quarter, starter_week)
  for (i in seq_along(paths)) {
    writeLines(starters[[i]](paths[i]), paths[i])
  }
  
  # 3) basic README to guide the user (optional)
  readme_path <- file.path(repo_dir, "README_TODOENGINE.md")
  if (!file.exists(readme_path) || overwrite) {
    readme <- c(
      "# To-Do Engine Project",
      "",
      "- Edit `todoengine_config.R` to tweak paths and options.",
      paste0("- Current week files live in: `", live_dir, "`"),
      paste0("- Archive lives in: `", archive_dir, "`"),
      "- Run `todoengine::run_monday()` each Monday (or set a cron job).",
      "- Edit `.txt` files directly in RStudio; Markdown/HTML mirrors are optional."
    )
    writeLines(readme, readme_path)
  }
  
  if (!has_git) {
    message("Note: '", repo_dir, "' does not look like a Git repo (no .git). ",
            "You can run `git init` there before committing archives.")
  }
  
  message("Initialized todoengine project at: ", repo_dir,
          "\n- Config: ", cfg_path,
          "\n- Live dir: ", live_dir,
          "\n- Archive dir: ", archive_dir,
          "\n- Seeded files: \n  - ", paste(basename(paths), collapse = "\n  - "))
  invisible(list(config = cfg_path, live_files = paths, archive_dir = archive_dir))
}
