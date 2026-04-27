# R/cli.R
#' Generate the new week's files (run on Mondays)
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @param preview If `TRUE`, return a `hacer_preview` instead of writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @export
run_monday <- function(date = Sys.Date(), cfg = todo_config(),
                       preview = .preview_default()) {
  if (!preview) {
    dir.create(cfg$live_dir, recursive = TRUE, showWarnings = FALSE)
    dir.create(cfg$archive_dir, recursive = TRUE, showWarnings = FALSE)
  }

  this_mon <- .monday_of(date)
  prev_mon <- this_mon - 7L

  prev_live <- .resolve_period_paths(prev_mon, cfg$live_dir)
  prev_arch <- .resolve_period_paths(prev_mon, cfg$archive_dir)
  if (!all(file.exists(prev_live)) && !all(file.exists(prev_arch))) {
    stop("Previous week's files not found in live or archive.")
  }
  src <- if (all(file.exists(prev_live))) prev_live else prev_arch
  prev <- list(live = prev_live, archive = prev_arch)

  daily   <- parse_todo(src[.period_types == "Daily"],   "Daily")
  week    <- parse_todo(src[.period_types == "Week"],    "Week")
  month   <- parse_todo(src[.period_types == "Month"],   "Month")
  quarter <- parse_todo(src[.period_types == "Quarter"], "Quarter")

  nxt <- advance_period(daily, week, month, quarter, prev_mon, this_mon)

  # Apply recurring manifest if present in the repo. Recurring items become
  # generated from the manifest; non-recurring user tasks carry forward.
  rec_path <- file.path(dirname(cfg$live_dir), "recurring.txt")
  if (file.exists(rec_path)) {
    rec <- read_recurring(rec_path)
    if (nrow(rec)) {
      daily_sections <- if (!is.null(cfg$daily_sections)) cfg$daily_sections
                        else c("Monday","Tuesday","Wednesday","Thursday","Friday")
      nxt$Daily <- .merge_recurring(
        .strip_recurring(nxt$Daily),
        .materialize_daily(rec, this_mon, daily_sections))
      nxt$Week    <- .merge_recurring(
        .strip_recurring(nxt$Week),
        .materialize_period(rec, "Week"))
      nxt$Month   <- .merge_recurring(
        .strip_recurring(nxt$Month),
        .materialize_period(rec, "Month"))
      nxt$Quarter <- .merge_recurring(
        .strip_recurring(nxt$Quarter),
        .materialize_period(rec, "Quarter"))
    }
  }

  dst <- paths_for(this_mon, cfg)
  targets <- list()
  for (p in .period_types) {
    df <- nxt[[p]]
    txt_path <- dst$live[.period_types == p]
    targets[[txt_path]] <- build_todo_txt_lines(df, txt_path, p, cfg)
    if (isTRUE(cfg$render_markdown)) {
      md_path <- sub("\\.txt$", ".md", txt_path)
      targets[[md_path]] <- build_markdown_lines(df, md_path, p, cfg)
    }
    if (isTRUE(cfg$render_html)) {
      html_path <- sub("\\.txt$", ".html", txt_path)
      targets[[html_path]] <- build_simple_html_lines(df, html_path, p)
    }
  }

  result <- .write_or_preview(targets, preview)

  # archive: copy previous live into archive, then git add/commit if the folder is a repo
  # This side effect only happens in non-preview mode.
  if (!preview && all(file.exists(prev$live))) {
    file.copy(from = prev$live, to = prev$archive, overwrite = TRUE)
    old_wd <- getwd(); on.exit(setwd(old_wd), add = TRUE)
    setwd(cfg$archive_dir)
    if (file.exists(file.path(cfg$archive_dir, ".git"))) {
      system2("git", c("add", "."))
      msg <- paste("Archive ToDos:", format(prev_mon))
      system2("git", c("commit", "-m", shQuote(msg)), stdout = FALSE, stderr = FALSE)
      system2("git", c("push"), stdout = FALSE, stderr = FALSE)
    }
  }

  if (!preview) return(invisible(dst$live))
  result
}

#' Infer a period name from a ToDo filename
#' @param f A filename or path like `ToDo_250915_Daily.txt`.
#' @export
infer_period_from_filename <- function(f){
  b <- basename(f)
  if (grepl("_daily", b, ignore.case = TRUE)) "Daily"
  else if (grepl("_week", b, ignore.case = TRUE)) "Week"
  else if (grepl("_month", b, ignore.case = TRUE)) "Month"
  else if (grepl("_quarter", b, ignore.case = TRUE)) "Quarter"
  else NA_character_
}

#' Roll up parent statuses in a single file
#' @param file_name Path to a ToDo `.txt` file.
#' @param preview If `TRUE`, return a `hacer_preview` instead of writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @export
fix_parents <- function(file_name, preview = .preview_default()){
  per <- infer_period_from_filename(file_name)
  df  <- parse_todo(file_name, per)
  df  <- inherit_recur_to_parents(df)
  df  <- rollup_status(df)
  per_eff <- ifelse(is.na(per), "Daily", per)
  new_lines <- build_todo_txt_lines(df, file_name, per_eff)
  targets <- list()
  targets[[file_name]] <- new_lines
  result <- .write_or_preview(targets, preview)
  if (!preview) return(invisible(file_name))
  result
}

# R/cli.R
#' Sync new items added in Daily up to Week/Month/Quarter
#' @param date A Date. Defaults to `Sys.Date()`.
#' @param cfg A config list from `todo_config()`.
#' @param preview If `TRUE`, return a `hacer_preview` instead of writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @export
sync_from_daily <- function(date = Sys.Date(), cfg = todo_config(),
                            preview = .preview_default()){
  mon <- .monday_of(date)
  live_paths <- .resolve_period_paths(mon, cfg$live_dir)
  d   <- parse_todo(live_paths[.period_types == "Daily"],   "Daily")
  W   <- parse_todo(live_paths[.period_types == "Week"],    "Week")
  M   <- parse_todo(live_paths[.period_types == "Month"],   "Month")
  Q   <- parse_todo(live_paths[.period_types == "Quarter"], "Quarter")

  add_missing <- function(src, tgt){
    if (!nrow(src)) return(tgt)
    need <- setdiff(src$path, tgt$path)
    if (!length(need)) return(tgt)
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

  w_path <- live_paths[.period_types == "Week"]
  m_path <- live_paths[.period_types == "Month"]
  q_path <- live_paths[.period_types == "Quarter"]
  targets <- list()
  targets[[w_path]] <- build_todo_txt_lines(W, w_path, "Week",  cfg)
  targets[[m_path]] <- build_todo_txt_lines(M, m_path, "Month", cfg)
  targets[[q_path]] <- build_todo_txt_lines(Q, q_path, "Quarter", cfg)

  result <- .write_or_preview(targets, preview)
  if (!preview) return(invisible(TRUE))
  result
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
#' @param preview If `TRUE`, return a `hacer_preview` instead of writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @export
next_day <- function(date = Sys.Date(), cfg = todo_config(),
                     preview = .preview_default()) {
  mon <- .monday_of(date)
  live_paths <- .resolve_period_paths(mon, cfg$live_dir)
  daily_file <- live_paths[.period_types == "Daily"]
  if (!file.exists(daily_file)) stop("Daily file not found: ", daily_file)

  lines <- readLines(daily_file, warn = FALSE)
  days <- cfg$daily_sections

  today_name <- weekdays(date)
  today_idx <- match(today_name, days)
  if (is.na(today_idx)) stop("Today (", today_name, ") not in daily_sections")
  if (today_idx >= length(days)) {
    message("Already at ", today_name, " (last day). Nothing to advance.")
    if (preview) return(.new_preview())
    return(invisible(daily_file))
  }
  tomorrow_name <- days[today_idx + 1L]

  section_starts <- grep("^#\\s+\\w", lines)
  section_names <- sub("^#\\s+", "", lines[section_starts])

  today_start <- section_starts[match(today_name, section_names)]
  tomorrow_start <- section_starts[match(tomorrow_name, section_names)]
  if (is.na(today_start) || is.na(tomorrow_start)) {
    stop("Could not find sections for ", today_name, " and ", tomorrow_name)
  }

  today_end <- tomorrow_start - 1L
  while (today_end > today_start && grepl("^\\s*$|^#", lines[today_end])) {
    today_end <- today_end - 1L
  }

  if (today_end < today_start) {
    message("No tasks in ", today_name, " section.")
    if (preview) return(.new_preview())
    return(invisible(daily_file))
  }
  today_lines <- lines[(today_start + 1L):today_end]

  copy_lines <- character()
  last_was_task <- FALSE
  for (ln in today_lines) {
    if (grepl("^\\s*$", ln)) {
      if (last_was_task) copy_lines <- c(copy_lines, "")
      last_was_task <- FALSE
      next
    }
    parsed <- .parse_task_line(ln)
    if (is.null(parsed)) next

    if (parsed$status == "x") next

    is_daily_recur <- grepl("^(Email|ToDo)$", parsed$name, ignore.case = TRUE)
    if (is_daily_recur && parsed$status == "/") next

    ln_reset <- sub("\\[/\\]", "[ ]", ln)
    ln_reset <- sub("\\[x\\]", "[ ]", ln_reset)
    copy_lines <- c(copy_lines, ln_reset)
    last_was_task <- TRUE
  }

  keep_today <- character()
  for (ln in today_lines) {
    parsed <- .parse_task_line(ln)
    if (is.null(parsed)) {
      keep_today <- c(keep_today, ln)
    } else if (parsed$status %in% c("/", "x", "!")) {
      keep_today <- c(keep_today, ln)
    }
  }

  separator_start <- tomorrow_start - 1L
  while (separator_start > today_end && grepl("^\\s*$", lines[separator_start])) {
    separator_start <- separator_start - 1L
  }

  new_lines <- c(
    lines[1:today_start],
    keep_today,
    "",
    lines[separator_start:tomorrow_start],
    "",
    copy_lines,
    "",
    if (tomorrow_start < length(lines)) lines[(tomorrow_start + 1L):length(lines)] else character()
  )

  targets <- list()
  targets[[daily_file]] <- new_lines
  result <- .write_or_preview(targets, preview)

  if (!preview) {
    message("Advanced from ", today_name, " to ", tomorrow_name)
    return(invisible(daily_file))
  }
  result
}
