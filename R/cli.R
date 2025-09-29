# R/cli.R
#' Generate the new week's files (run on Mondays)
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

infer_period_from_filename <- function(f){
  b <- basename(f)
  if (grepl("_Daily", b)) "Daily" else if (grepl("_Week", b)) "Week" else
    if (grepl("_Month", b)) "Month" else if (grepl("_Quarter", b)) "Quarter" else NA_character_
}

#' Roll up parent statuses in a single file
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
