# R/catch_up.R

.todo_dates_in <- function(paths) {
  files <- unlist(lapply(paths, function(p) {
    if (!dir.exists(p)) character() else list.files(p, full.names = TRUE)
  }), use.names = FALSE)
  if (!length(files)) return(as.Date(character()))
  b <- basename(files)
  hit <- regexpr("[0-9]{6}", b)
  vals <- regmatches(b, hit)
  vals <- vals[nchar(vals) == 6L]
  if (!length(vals)) return(as.Date(character()))
  as.Date(paste0("20", substr(vals, 1L, 2L), "-",
                 substr(vals, 3L, 4L), "-",
                 substr(vals, 5L, 6L)))
}

#' Catch a todo repo up to the current week
#'
#' Rolls missing Monday files forward from the latest live/archive week to
#' the week containing \code{date}. This is intentionally conservative: it
#' creates missing week files but does not edit daily sections inside the
#' current week.
#'
#' @param date Date to catch up to. Defaults to today.
#' @param cfg Config list from \code{todo_config()}.
#' @param preview If TRUE, report planned roll dates without writing.
#' @return Character vector of Monday dates rolled, invisibly.
#' @export
catch_up <- function(date = Sys.Date(), cfg = todo_config(),
                     preview = .preview_default()) {
  target <- .monday_of(date)
  dates <- .todo_dates_in(c(cfg$live_dir, cfg$archive_dir))
  if (!length(dates)) {
    stop("No todo files found in live_dir or archive_dir", call. = FALSE)
  }
  current <- .monday_of(max(dates, na.rm = TRUE))
  if (is.na(current)) {
    stop("Could not infer latest todo week", call. = FALSE)
  }
  rolled <- as.Date(character())
  while (current < target) {
    current <- current + 7L
    rolled <- c(rolled, current)
    if (!preview) {
      run_monday(date = current, cfg = cfg, preview = FALSE)
    }
  }
  if (!length(rolled)) {
    message("Todo repo already at week of ", format(target))
  } else if (preview) {
    message("Would roll todo repo through: ",
            paste(format(rolled), collapse = ", "))
  } else {
    message("Rolled todo repo through week of ", format(target))
  }
  invisible(rolled)
}
