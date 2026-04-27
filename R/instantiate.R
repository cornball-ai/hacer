#' Create a hacer project layout in a Git repo.
#' @param repo_dir Path to your ToDo repo directory.
#' @param syncthing_live_dir Optional path to a Syncthing-shared live directory.
#' @param overwrite Overwrite existing files? Default `FALSE`.
#' @param preview If `TRUE`, return a `hacer_preview` instead of writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @export
instantiate_todo <- function(repo_dir,
                             syncthing_live_dir = NULL,
                             overwrite = FALSE,
                             preview = .preview_default()) {
  repo_dir <- normalizePath(path.expand(repo_dir), mustWork = FALSE)
  if (!preview && !dir.exists(repo_dir)) {
    dir.create(repo_dir, recursive = TRUE, showWarnings = FALSE)
  }

  has_git <- file.exists(file.path(repo_dir, ".git"))

  live_dir <- if (is.null(syncthing_live_dir)) file.path(repo_dir, "this_week")
  else normalizePath(path.expand(syncthing_live_dir), mustWork = FALSE)
  archive_dir <- file.path(repo_dir, "archive")

  if (!preview) {
    dir.create(live_dir, recursive = TRUE, showWarnings = FALSE)
    dir.create(archive_dir, recursive = TRUE, showWarnings = FALSE)
  }

  cfg_path <- file.path(repo_dir, "hacer_config.R")
  if (file.exists(cfg_path) && !overwrite) {
    stop("Config already exists at ", cfg_path, ". Set overwrite=TRUE to replace.")
  }

  cfg_lines <- c(
    "## Local configuration for hacer",
    paste0("# ", repo_dir, "/hacer_config.R"),
    "todo_config_local <- list(",
    "  tz = 'America/Chicago',",
    "  indent = 2L,",
    paste0("  live_dir    = '", live_dir, "',"),
    paste0("  archive_dir = '", archive_dir, "',"),
    "  filename_fmt = 'todo_%y%m%d_%s.md',",
    "  daily_sections = c('Monday','Tuesday','Wednesday','Thursday','Friday'),",
    "  render_html = TRUE",
    ")"
  )

  mon <- .monday_of(Sys.Date())
  files <- .build_names_for(mon)
  paths <- file.path(live_dir, files)

  if (any(file.exists(paths)) && !overwrite) {
    stop("Initial ToDo files already exist in live_dir; set overwrite=TRUE to replace.")
  }

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

  targets <- list()
  targets[[cfg_path]] <- cfg_lines
  for (i in seq_along(paths)) {
    targets[[paths[i]]] <- starters[[i]](paths[i])
  }

  readme_path <- file.path(repo_dir, "README_HACER.md")
  if (!file.exists(readme_path) || overwrite) {
    targets[[readme_path]] <- c(
      "# ToDo Project",
      "",
      "- Edit `hacer_config.R` to tweak paths and options.",
      paste0("- Current week files live in: `", live_dir, "`"),
      paste0("- Archive lives in: `", archive_dir, "`"),
      "- Recurring tasks declared in `recurring.txt`; `run_monday()` materializes them.",
      "- Edit `.txt` files directly in RStudio; Markdown/HTML mirrors are optional."
    )
  }

  recurring_path <- file.path(repo_dir, "recurring.txt")
  if (!file.exists(recurring_path) || overwrite) {
    targets[[recurring_path]] <- c(
      "# recurring.txt - tasks that repeat by frequency",
      "#",
      "# Format: <freq>  <path>",
      "#   Day codes:  M T W R F  (R = Thursday)",
      "#   Combine adjacently:  MR = Mon+Thu, MTWRF = every weekday, * = MTWRF",
      "#   Week-of-month prefix: 1W..5W (e.g. 1W:M = first Monday of month)",
      "#",
      "# run_monday() reads this file and materializes the recurring rows into",
      "# each day section of Daily, plus a flat list in Week/Month/Quarter.",
      "",
      "M       Email",
      "M       todo",
      "MR      wiki",
      "*       Exercise",
      "1W:M    Bills"
    )
  }

  result <- .write_or_preview(targets, preview)

  if (!preview) {
    if (!has_git) {
      message("Note: '", repo_dir, "' does not look like a Git repo (no .git). ",
              "You can run `git init` there before committing archives.")
    }
    message("Initialized hacer project at: ", repo_dir,
            "\n- Config: ", cfg_path,
            "\n- Live dir: ", live_dir,
            "\n- Archive dir: ", archive_dir,
            "\n- Seeded files: \n  - ", paste(basename(paths), collapse = "\n  - "))
    return(invisible(list(config = cfg_path, live_files = paths,
                          archive_dir = archive_dir)))
  }
  result
}
