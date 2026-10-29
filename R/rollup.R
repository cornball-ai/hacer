# R/rollup.R
#' Roll child statuses up to parent tasks
#'
#' A parent is `x` when every child is `x`, `/` when any child is `/` or
#' `x`, and blank otherwise. `[!]` (important) is a marker on the item
#' itself: an important child counts as open for its parent, and an
#' important parent keeps its marker until all of its children are done.
#'
#' @param df A parsed ToDo data.frame.
#' @export
rollup_status <- function(df) {
  if (!nrow(df)) return(df)
  levs <- sort(unique(df$level), decreasing = TRUE)
  for (lvl in levs) {
    # for parents at level-1
    parents <- unique(df$parent_id[df$level == lvl & !is.na(df$parent_id)])
    for (p in parents) {
      kids <- df$status[!is.na(df$parent_id) & df$parent_id == p]
      if (!length(kids)) next
      new <- if (all(kids == "x")) "x"
      else if (any(kids %in% c("/", "x"))) "/"
      else " "
      is_p <- df$id == p
      if (new != "x" && any(df$status[is_p] == "!")) new <- "!"
      df$status[is_p] <- new
    }
  }
  df
}
