# R/recurring.R
# Recurring-task manifest: a plain-text file declaring which tasks repeat
# and on which weekdays. run_monday() reads this and materializes the
# recurring rows for each day section, so day-by-day duplication in Daily
# is no longer the source of truth.
#
# Format:
#   # Comments allowed
#   <freq>  <path>
#
#   M       Email                                    # Mondays only
#   MR      wiki                                     # Mon + Thu
#   *       Exercise                                 # every weekday
#   MTWRF   Exercise                                 # same as *
#   1W:M    Bills                                    # first Monday of month
#   MTWR    cornball.ai > Lil Casey > Countdown      # nested path
#
# Day codes: M T W R F (R = Thursday). Combine adjacently. * means MTWRF.
# Optional week-of-month: 1W..5W, where week N is "the week whose Monday
# has day-of-month in 7*(N-1)+1 .. 7*N". Combine with days via colon.

.day_codes <- c(M = 1L, T = 2L, W = 3L, R = 4L, F = 5L)

# Parse one frequency token. Returns list(days = int vec, week_of_month = int or NA).
.parse_freq <- function(token) {
  token <- trimws(token)
  wom <- NA_integer_
  m <- regmatches(token, regexec("^([1-5])W(?::(.+))?$", token, perl = TRUE))[[1]]
  if (length(m) == 3L) {
    wom <- as.integer(m[2])
    days_part <- m[3]
    if (!nzchar(days_part)) days_part <- "*"
    token <- days_part
  }
  if (token == "*") token <- "MTWRF"
  chars <- strsplit(token, "", fixed = TRUE)[[1]]
  bad <- chars[!chars %in% names(.day_codes)]
  if (length(bad)) {
    stop("Bad day code(s) in frequency: ", paste(bad, collapse = ""))
  }
  days <- unique(unname(.day_codes[chars]))
  list(days = sort(days), week_of_month = wom)
}

#' Read a recurring-task manifest
#'
#' @param path Path to a `recurring.txt` file.
#' @return A `data.frame` with columns `freq`, `days` (list-column of int
#'   vectors), `week_of_month` (int or `NA`), `path`, `name`, `parent_path`,
#'   `level`, `order`.
#' @export
read_recurring <- function(path) {
  if (!file.exists(path)) {
    return(.empty_recurring_df())
  }
  lines <- readLines(path, warn = FALSE)
  freq <- character(); paths <- character()
  for (ln in lines) {
    s <- sub("\\s*#.*$", "", ln)         # strip inline comments
    s <- trimws(s)
    if (!nzchar(s)) next
    parts <- regmatches(s, regexec("^(\\S+)\\s+(.+)$", s))[[1]]
    if (length(parts) != 3L) {
      stop("Cannot parse recurring line: ", ln)
    }
    freq <- c(freq, parts[2])
    paths <- c(paths, trimws(parts[3]))
  }
  if (!length(freq)) return(.empty_recurring_df())

  parsed <- lapply(freq, .parse_freq)
  days <- lapply(parsed, `[[`, "days")
  wom  <- vapply(parsed, function(x) x$week_of_month, integer(1L))
  names <- vapply(strsplit(paths, " > ", fixed = TRUE),
                  function(x) x[length(x)], character(1L))
  parent_path <- vapply(strsplit(paths, " > ", fixed = TRUE), function(x) {
    if (length(x) <= 1L) NA_character_
    else paste(x[-length(x)], collapse = " > ")
  }, character(1L))
  level <- vapply(strsplit(paths, " > ", fixed = TRUE),
                  function(x) length(x) - 1L, integer(1L))
  data.frame(
    freq          = freq,
    days          = I(days),
    week_of_month = wom,
    path          = paths,
    name          = names,
    parent_path   = parent_path,
    level         = level,
    order         = seq_along(freq),
    stringsAsFactors = FALSE
  )
}

.empty_recurring_df <- function() {
  data.frame(
    freq          = character(),
    days          = I(list()),
    week_of_month = integer(),
    path          = character(),
    name          = character(),
    parent_path   = character(),
    level         = integer(),
    order         = integer(),
    stringsAsFactors = FALSE
  )
}

# Day-of-week index 1..5 (Mon..Fri) for a Date. Returns NA for Sat/Sun.
.weekday_idx <- function(date) {
  w <- as.POSIXlt(date)$wday              # 0=Sun, 1=Mon, ..., 6=Sat
  if (w == 0L || w == 6L) NA_integer_ else as.integer(w)
}

# Week-of-month for a date: floor((day - 1) / 7) + 1 ranges 1..5.
.week_of_month <- function(date) {
  ((as.POSIXlt(date)$mday - 1L) %/% 7L) + 1L
}

# Filter manifest rows that apply on a given date.
.recurring_for_date <- function(rec, date) {
  if (!nrow(rec)) return(rec)
  dow <- .weekday_idx(date)
  if (is.na(dow)) return(rec[FALSE, , drop = FALSE])
  wom <- .week_of_month(date)
  hits <- vapply(seq_len(nrow(rec)), function(i) {
    if (!(dow %in% rec$days[[i]])) return(FALSE)
    if (!is.na(rec$week_of_month[i]) && rec$week_of_month[i] != wom) return(FALSE)
    TRUE
  }, logical(1L))
  rec[hits, , drop = FALSE]
}

# Expand a manifest subset into a parse_todo-shaped data.frame for one
# section. Ancestors of nested paths are auto-emitted as recurring containers
# so the tree is well-formed.
.expand_recurring <- function(rec_subset, period, section, start_order = 1L) {
  schema_empty <- function() {
    data.frame(
      id = character(), parent_id = character(),
      period = character(), section = character(),
      name = character(), recur = logical(), status = character(),
      level = integer(), order = integer(), path = character(),
      stringsAsFactors = FALSE)
  }
  if (!nrow(rec_subset)) return(schema_empty())

  rows <- list()
  emitted <- character()
  ord <- start_order - 1L

  for (i in seq_len(nrow(rec_subset))) {
    parts <- strsplit(rec_subset$path[i], " > ", fixed = TRUE)[[1]]
    cur <- character()
    for (j in seq_along(parts)) {
      cur <- c(cur, parts[j])
      pth <- paste(cur, collapse = " > ")
      if (pth %in% emitted) next
      ord <- ord + 1L
      parent <- if (j == 1L) NA_character_
                else paste(cur[-length(cur)], collapse = " > ")
      rows[[length(rows) + 1L]] <- data.frame(
        id = pth, parent_id = parent,
        period = period, section = section,
        name = parts[j], recur = TRUE, status = " ",
        level = j - 1L, order = ord, path = pth,
        stringsAsFactors = FALSE)
      emitted <- c(emitted, pth)
    }
  }
  do.call(rbind, rows)
}

# Materialize the recurring rows for one Daily file across all day sections.
# Returns a parse_todo-shaped df with multiple sections (one per applicable
# weekday). monday_date is the Monday of the week being generated.
.materialize_daily <- function(rec, monday_date, daily_sections) {
  schema_empty <- function() {
    data.frame(
      id = character(), parent_id = character(),
      period = character(), section = character(),
      name = character(), recur = logical(), status = character(),
      level = integer(), order = integer(), path = character(),
      stringsAsFactors = FALSE)
  }
  if (!nrow(rec)) return(schema_empty())

  out <- list()
  for (k in seq_along(daily_sections)) {
    day_date <- monday_date + (k - 1L)
    day_name <- daily_sections[k]
    rec_today <- .recurring_for_date(rec, day_date)
    if (!nrow(rec_today)) next
    expanded <- .expand_recurring(
      rec_today, period = "Daily", section = day_name,
      start_order = (k - 1L) * 1000L + 1L)
    out[[length(out) + 1L]] <- expanded
  }
  if (!length(out)) return(schema_empty())
  do.call(rbind, out)
}

# Materialize recurring as a flat list for Week/Month/Quarter (no sections).
# All recurring items appear once at their declared path.
.materialize_period <- function(rec, period) {
  schema_empty <- function() {
    data.frame(
      id = character(), parent_id = character(),
      period = character(), section = character(),
      name = character(), recur = logical(), status = character(),
      level = integer(), order = integer(), path = character(),
      stringsAsFactors = FALSE)
  }
  if (!nrow(rec)) return(schema_empty())
  out <- .expand_recurring(rec, period = period,
                           section = NA_character_, start_order = 1L)
  out
}

# Drop recurring rows from a carry-forward df (after advance_period).
.strip_recurring <- function(df) {
  if (!nrow(df)) return(df)
  df[!isTRUE_vec(df$recur), , drop = FALSE]
}

isTRUE_vec <- function(x) {
  x <- as.logical(x)
  ifelse(is.na(x), FALSE, x)
}

# Merge recurring (rec) with carry-forward non-recurring (carry).
# Per section (or globally for non-Daily), recurring rows go first in
# manifest order, then carry rows in their existing order. Ancestors are
# synthesized for any orphan paths in carry.
.merge_recurring <- function(carry, rec) {
  if (!nrow(rec)) return(carry)
  if (!nrow(carry)) {
    rec$order <- seq_len(nrow(rec))
    return(rec)
  }
  # Drop carry rows that are duplicated in rec (rec wins on path).
  carry_only <- carry[!(carry$path %in% rec$path), , drop = FALSE]

  # Ensure all ancestor paths present (for orphan carry entries with rec parents).
  needed <- character()
  for (p in carry_only$path) {
    parts <- strsplit(p, " > ", fixed = TRUE)[[1]]
    if (length(parts) <= 1L) next
    for (j in seq_len(length(parts) - 1L)) {
      anc <- paste(parts[seq_len(j)], collapse = " > ")
      if (!(anc %in% rec$path) && !(anc %in% carry_only$path)) {
        needed <- c(needed, anc)
      }
    }
  }
  needed <- unique(needed)
  if (length(needed)) {
    anc_rows <- lapply(needed, function(p) {
      parts <- strsplit(p, " > ", fixed = TRUE)[[1]]
      data.frame(
        id = p,
        parent_id = if (length(parts) == 1L) NA_character_
                    else paste(parts[-length(parts)], collapse = " > "),
        period = unique(carry$period)[1],
        section = NA_character_,
        name = parts[length(parts)],
        recur = FALSE, status = " ",
        level = length(parts) - 1L,
        order = max(carry$order, 0L) + 1L,
        path = p, stringsAsFactors = FALSE)
    })
    carry_only <- rbind(carry_only, do.call(rbind, anc_rows))
  }

  # Ordering: recurring first (preserving its order), then carry.
  carry_only$order <- max(rec$order) + carry_only$order
  out <- rbind(rec, carry_only)
  out
}
