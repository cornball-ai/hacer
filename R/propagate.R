# R/propagate.R
# Priority order: " " < "/" < "x"
.pmax_status <- function(a, b) {
  map <- c(" " = 0L, "/" = 1L, "x" = 2L)
  out <- a
  idx <- (map[b] > map[a])
  out[idx] <- b[idx]
  out
}

#' @export
propagate_from_daily <- function(daily, target) {
  if (!nrow(daily) || !nrow(target)) return(target)
  m <- match(target$path, daily$path)
  hit <- !is.na(m)
  target$status[hit] <- .pmax_status(target$status[hit], daily$status[m[hit]])
  target
}
