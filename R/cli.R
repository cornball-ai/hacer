# R/cli.R
#' Generate the new week's files (run on Mondays)
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @export
run_monday <- function(date = Sys.Date(), cfg = todo_config()) {
  dir.create(cfg$live_dir, recursive = TRUE, showWarnings = FALSE)
  dir.create(cfg$archive_dir, recursive = TRUE, showWarnings = FALSE)
  
  this_mon <- .monday_of(date)
  # find previous Monday by subtracting 7 days
  prev_mon <- this_mon - 7L
  
  # locate previous set in archive or live
  prev <- paths_for(prev_mon, cfg)
  if (!all(file.exists(prev$live)) && !all(file.exists(prev$archive))) {
    stop("Previous week's files not found in live or archive.")
  }
  src <- if (all(file.exists(prev$live))) prev$live else prev$archive
  
  # read previous
  daily   <- parse_todo(src[.period_types == "Daily"],   "Daily")
  week    <- parse_todo(src[.period_types == "Week"],    "Week")
  month   <- parse_todo(src[.period_types == "Month"],   "Month")
  quarter <- parse_todo(src[.period_types == "Quarter"], "Quarter")
  
  # advance and build new tables
  nxt <- advance_period(daily, week, month, quarter, prev_mon, this_mon)
  
  # write to live (Syncthing)
  dst <- paths_for(this_mon, cfg)
  for (p in .period_types) {
    df <- nxt[[p]]
    write_todo_txt(df, dst$live[.period_types==p], p, cfg)
    if (isTRUE(cfg$render_markdown)) {
      write_markdown(df, sub("\\.txt$", ".md", dst$live[.period_types==p]), p, cfg)
    }
    if (isTRUE(cfg$render_html)) {
      write_simple_html(df, sub("\\.txt$", ".html", dst$live[.period_types==p]), p)
    }
  }
  
  # archive: copy previous live into archive, then git add/commit if the folder is a repo
  if (all(file.exists(prev$live))) {
    file.copy(from = prev$live, to = prev$archive, overwrite = TRUE)
    # best-effort git (no dependency)
    old_wd <- getwd(); on.exit(setwd(old_wd), add = TRUE)
    setwd(cfg$archive_dir)
    if (file.exists(file.path(cfg$archive_dir, ".git"))) {
      system2("git", c("add", "."))
      msg <- paste("Archive ToDos:", format(prev_mon))
      system2("git", c("commit", "-m", shQuote(msg)), stdout = FALSE, stderr = FALSE)
      # optional push:
      system2("git", c("push"), stdout = FALSE, stderr = FALSE)
    }
  }
  
  invisible(dst$live)
}

#' Infer a period name from a ToDo filename
#' @param f A filename or path like `ToDo_250915_Daily.txt`.
#' @export
infer_period_from_filename <- function(f){
  b <- basename(f)
  if (grepl("_Daily", b)) "Daily" else if (grepl("_Week", b)) "Week" else
    if (grepl("_Month", b)) "Month" else if (grepl("_Quarter", b)) "Quarter" else NA_character_
}

#' Roll up parent statuses in a single file
#' @param file_name Path to a ToDo `.txt` file.
#' @export
fix_parents <- function(file_name){
  per <- infer_period_from_filename(file_name)
  df  <- parse_todo(file_name, per)
  df  <- inherit_recur_to_parents(df)
  df  <- rollup_status(df)
  write_todo_txt(df, file_name, ifelse(is.na(per), "Daily", per))
  invisible(file_name)
}

# R/cli.R
#' Sync new items added in Daily up to Week/Month/Quarter
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @export
sync_from_daily <- function(date = Sys.Date(), cfg = todo_config()){
  p   <- paths_for(date, cfg)
  d   <- parse_todo(p$live[grepl("_Daily", p$live)], "Daily")
  W   <- parse_todo(p$live[grepl("_Week",  p$live)], "Week")
  M   <- parse_todo(p$live[grepl("_Month", p$live)], "Month")
  Q   <- parse_todo(p$live[grepl("_Quarter",p$live)], "Quarter")
  
  add_missing <- function(src, tgt){
    if (!nrow(src)) return(tgt)
    need <- setdiff(src$path, tgt$path)
    if (!length(need)) return(tgt)
    # append missing paths (and any missing ancestors)
    append_path <- function(tgt, fullpath, section){
      parts <- strsplit(fullpath, " > ", fixed=TRUE)[[1]]
      cur <- character()
      for (i in seq_along(parts)) {
        cur <- c(cur, parts[i])
        pth <- paste(cur, collapse=" > ")
        if (!(pth %in% tgt$path)) {
          parent <- if (i==1) NA_character_ else paste(cur[-length(cur)], collapse=" > ")
          newrow <- data.frame(
            id = pth, parent_id = parent, period = unique(tgt$period)[1],
            section = if (unique(tgt$period)[1]=="Daily") section else NA_character_,
            name = parts[i], recur = FALSE, status = " ",
            level = i-1L, order = if (nrow(tgt)) max(tgt$order)+1L else 1L,
            path = pth, stringsAsFactors = FALSE
          )
          tgt <- rbind(tgt, newrow)
        }
      }
      tgt
    }
    for (pth in need) {
      sec <- NA_character_
      if ("section" %in% names(src)) {
        sec <- src$section[match(pth, src$path)]
      }
      tgt <- append_path(tgt, pth, sec)
    }
    tgt
  }
  
  W <- add_missing(d, W);  M <- add_missing(d, M);  Q <- add_missing(d, Q)
  W <- inherit_recur_to_parents(W); M <- inherit_recur_to_parents(M); Q <- inherit_recur_to_parents(Q)
  W <- rollup_status(W);             M <- rollup_status(M);             Q <- rollup_status(Q)
  write_todo_txt(W, p$live[grepl("_Week",    p$live)], "Week",  cfg)
  write_todo_txt(M, p$live[grepl("_Month",   p$live)], "Month", cfg)
  write_todo_txt(Q, p$live[grepl("_Quarter", p$live)], "Quarter", cfg)
  invisible(TRUE)
}

#' Advance tasks from today to tomorrow within the Daily file
#'
#' Copies tasks from today's section to tomorrow's section (except completed
#' items and daily recurring like Email/ToDo if marked done). Then removes
#' unchecked items from today, keeping only in-progress and completed tasks
#' as a record of what was actually worked on.
#'
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @export
next_day <- function(date = Sys.Date(), cfg = todo_config()) {
  p <- paths_for(date, cfg)
  daily_file <- p$live[grepl("_Daily", p$live)]
  if (!file.exists(daily_file)) stop("Daily file not found: ", daily_file)

  lines <- readLines(daily_file, warn = FALSE)
  days <- cfg$daily_sections  # e.g., c("Monday", "Tuesday", ...)

  # Determine today's weekday name

  today_name <- weekdays(date)
  today_idx <- match(today_name, days)
  if (is.na(today_idx)) stop("Today (", today_name, ") not in daily_sections")
  if (today_idx >= length(days)) {
    message("Already at ", today_name, " (last day). Nothing to advance.")
    return(invisible(daily_file))
  }
  tomorrow_name <- days[today_idx + 1L]

  # Find section boundaries
  section_starts <- grep("^#\\s+\\w", lines)
  section_names <- sub("^#\\s+", "", lines[section_starts])

  today_start <- section_starts[match(today_name, section_names)]
  tomorrow_start <- section_starts[match(tomorrow_name, section_names)]
  if (is.na(today_start) || is.na(tomorrow_start)) {
    stop("Could not find sections for ", today_name, " and ", tomorrow_name)
  }

  # Find end of today's section (line before tomorrow or next section)
  today_end <- tomorrow_start - 1L
  while (today_end > today_start && grepl("^\\s*$|^#", lines[today_end])) {
    today_end <- today_end - 1L
  }

  # Extract today's task lines
  if (today_end < today_start) {
    message("No tasks in ", today_name, " section.")
    return(invisible(daily_file))
  }
  today_lines <- lines[(today_start + 1L):today_end]

  # Filter for copying to tomorrow:
  # - Skip [x] completed items
  # - Skip Email/ToDo if [/] (daily recurring that got done)
  # - Keep blank lines between top-level tasks
  copy_lines <- character()
  last_was_task <- FALSE
  for (ln in today_lines) {
    # Keep blank lines (they separate top-level task groups)
    if (grepl("^\\s*$", ln)) {
      if (last_was_task) copy_lines <- c(copy_lines, "")
      last_was_task <- FALSE
      next
    }
    if (!grepl("^\\s*\\[", ln)) next  # not a task line

    status <- substr(sub("^\\s*", "", ln), 2, 2)
    if (status == "x") next  # skip completed

    # Check if it's Email or ToDo with [/]
    is_daily_recur <- grepl("-\\s*\\*?(Email|ToDo)\\s*$", ln, ignore.case = TRUE)
    if (is_daily_recur && status == "/") next  # skip done daily recurring

    # Reset status to blank for tomorrow
    ln_reset <- sub("\\[/\\]", "[ ]", ln)
    ln_reset <- sub("\\[x\\]", "[ ]", ln_reset)  # just in case
    copy_lines <- c(copy_lines, ln_reset)
    last_was_task <- TRUE
  }

  # Filter today's section: keep only [/] and [x], remove [ ]
  keep_today <- character()
  for (ln in today_lines) {
    if (!grepl("^\\s*\\[", ln)) {
      # Keep non-task lines (blanks, etc.)
      keep_today <- c(keep_today, ln)
    } else {
      status <- substr(sub("^\\s*", "", ln), 2, 2)
      if (status %in% c("/", "x", "!")) {
        keep_today <- c(keep_today, ln)
      }
      # Drop [ ] unchecked items
    }
  }

  # Find the separator line before tomorrow (e.g., #######################################)
  separator_start <- tomorrow_start - 1L
  while (separator_start > today_end && grepl("^\\s*$", lines[separator_start])) {
    separator_start <- separator_start - 1L
  }
  # separator_start now points to the ### line (or today_end if none)

  # Build new file
  new_lines <- c(
    lines[1:today_start],            # everything up to and including today header
    keep_today,                       # filtered today tasks
    "",                               # blank line
    lines[separator_start:tomorrow_start],  # separator + blank + tomorrow header
    "",                               # blank after header
    copy_lines,                       # copied tasks
    "",                               # blank line
    if (tomorrow_start < length(lines)) lines[(tomorrow_start + 1L):length(lines)] else character()
  )

  # Remove excess blank lines
  writeLines(new_lines, daily_file)
  message("Advanced from ", today_name, " to ", tomorrow_name)
  invisible(daily_file)
}
