# R/advance.R
.is_new_month <- function(prev_monday, next_monday) {
  pm <- as.POSIXlt(prev_monday); nm <- as.POSIXlt(next_monday)
  pm$mon != nm$mon || pm$year != nm$year
}
.is_new_quarter <- function(prev_monday, next_monday) {
  f <- function(d) floor((as.POSIXlt(d)$mon) / 3L)
  (f(prev_monday) != f(next_monday)) || (as.POSIXlt(prev_monday)$year != as.POSIXlt(next_monday)$year)
}

# drop x without recur; keep /; keep * always (reset x->" " when rolling)
.drop_done_nonrecur <- function(df) {
  keep <- !(df$status == "x" & !df$recur)
  df[keep, , drop = FALSE]
}

.reset_recurs_if_done <- function(df) {
  if (!nrow(df)) return(df)
  ix <- which(df$recur & df$status == "x")
  if (length(ix)) df$status[ix] <- " "
  df
}

advance_period <- function(daily, week, month, quarter, prev_monday, next_monday) {
  # 1) propagate from daily
  week    <- propagate_from_daily(daily, week)
  month   <- propagate_from_daily(daily, month)
  quarter <- propagate_from_daily(daily, quarter)
  
  # 1.5
  daily   <- inherit_recur_to_parents(daily)
  week    <- inherit_recur_to_parents(week)
  month   <- inherit_recur_to_parents(month)
  quarter <- inherit_recur_to_parents(quarter)
  
  # 2) roll up parents
  daily   <- rollup_status(daily)
  week    <- rollup_status(week)
  month   <- rollup_status(month)
  quarter <- rollup_status(quarter)
  
  # 3) next Daily/Week: drop x (non-recur), keep /, keep *
  next_daily <- .reset_recurs_if_done(.drop_done_nonrecur(daily))
  next_week  <- .reset_recurs_if_done(.drop_done_nonrecur(week))
  
  # 4) month/quarter rollover clearing (remove x on turnover)
  if (.is_new_month(prev_monday, next_monday)) {
    month <- month[!(month$status == "x" & !month$recur), , drop = FALSE]
    # also reset any recured x back to blank
    month <- .reset_recurs_if_done(month)
  }
  if (.is_new_quarter(prev_monday, next_monday)) {
    quarter <- quarter[!(quarter$status == "x" & !quarter$recur), , drop = FALSE]
    quarter <- .reset_recurs_if_done(quarter)
  }
  
  list(Daily = next_daily, Week = next_week, Month = month, Quarter = quarter)
}

inherit_recur_to_parents <- function(df){
  if (!nrow(df)) return(df)
  df$recur <- as.logical(df$recur)
  levs <- sort(unique(df$level), decreasing = TRUE)
  for (lvl in levs) {
    parents <- unique(df$parent_id[df$level == lvl & !is.na(df$parent_id)])
    for (p in parents) {
      if (any(df$recur[df$parent_id == p], na.rm = TRUE)) df$recur[df$id == p] <- TRUE
    }
  }
  df
}

