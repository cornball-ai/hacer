# R/rollup.R
rollup_status <- function(df) {
  if (!nrow(df)) return(df)
  levs <- sort(unique(df$level), decreasing = TRUE)
  for (lvl in levs) {
    # for parents at level-1
    parents <- unique(df$parent_id[df$level == lvl & !is.na(df$parent_id)])
    for (p in parents) {
      kids <- df$status[df$parent_id == p]
      if (!length(kids)) next
      new <- if (all(kids == "x")) "x"
      else if (any(kids == "/") || any(kids == "x")) "/"
      else " "
      df$status[df$id == p] <- new
    }
  }
  df
}
