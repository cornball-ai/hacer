# R/parse.R

# Parse a single ToDo line. Returns NULL for non-task lines.
# Recognizes both formats:
#   - markdown: "- [X] text" or "  - [X] *text"
#   - legacy:   "[X] - text" or "[X] -*text"
# The `*` recurring marker is parsed in either format for backwards compat,
# even though the markdown writer no longer emits it.
.parse_task_line <- function(ln, indent = 2L) {
  stripped <- sub("^\\s+", "", ln)
  nspaces <- nchar(ln) - nchar(stripped)
  level <- as.integer(nspaces / indent)

  md  <- regmatches(stripped,
                    regexec("^-\\s+\\[( |/|x|!)\\]\\s+(.*)$", stripped))[[1]]
  if (length(md) == 3L) {
    status <- md[2]
    rest <- md[3]
  } else {
    leg <- regmatches(stripped,
                      regexec("^\\[( |/|x|!)\\]\\s*-\\s*(.*)$", stripped))[[1]]
    if (length(leg) == 3L) {
      status <- leg[2]
      rest <- leg[3]
    } else {
      return(NULL)
    }
  }

  recur <- FALSE
  if (grepl("^\\*", rest)) {
    recur <- TRUE
    rest <- sub("^\\*", "", rest)
  }
  list(level = level, status = status, recur = recur, name = trimws(rest))
}

#' Parse a ToDo file into a data.frame
#'
#' Accepts both the new markdown task-list format (`- [X] text`) and the
#' legacy `[X] - text` format, so repos in mid-migration keep parsing.
#' Returns a data.frame with columns: id, parent_id, period, section, name,
#' recur, status, level, order, path.
#'
#' @param file Path to a ToDo file (`.md` preferred, `.txt` still readable).
#' @param period One of "Daily", "Week", "Month", "Quarter", or `NA`.
#' @param indent Spaces per indent level. Defaults to `todo_config()$indent`.
#' @export
parse_todo <- function(file, period = NA_character_, indent = NULL) {
  if (is.null(indent)) indent <- todo_config()$indent
  if (!file.exists(file)) stop("Missing file: ", file)
  lines <- readLines(file, warn = FALSE)
  out <- vector("list", length(lines))
  sec <- NA_character_
  ord <- 0L
  stk_ids <- character(32L)
  stk_paths <- character(32L)

  make_row <- function(level, section, name, recur, status, order, parent_id, path) {
    list(
      id = paste0(path), parent_id = parent_id, period = period, section = section,
      name = name, recur = recur, status = status, level = level,
      order = order, path = path
    )
  }

  n <- 0L
  for (ln in lines) {
    if (grepl("^#+\\s+", ln)) {
      sec <- sub("^#+\\s*", "", ln)
      next
    }
    parsed <- .parse_task_line(ln, indent)
    if (is.null(parsed)) next

    level  <- parsed$level
    status <- parsed$status
    recur  <- parsed$recur
    name   <- parsed$name

    if (level == 0L) {
      parent_id <- NA_character_
      path <- name
    } else {
      parent_id <- stk_ids[level]
      base_path <- stk_paths[level]
      if (is.na(base_path) || base_path == "") base_path <- ""
      path <- if (base_path == "") name else paste(base_path, name, sep = " > ")
    }
    stk_ids[level + 1L]   <- path
    stk_paths[level + 1L] <- path

    ord <- ord + 1L
    n <- n + 1L
    out[[n]] <- make_row(level, sec, name, recur, status, ord, parent_id, path)
  }
  if (n == 0L) {
    return(data.frame(id=character(), parent_id=character(), period=character(),
                      section=character(), name=character(), recur=logical(),
                      status=character(), level=integer(), order=integer(),
                      path=character(), stringsAsFactors = FALSE))
  }
  df <- do.call(rbind, lapply(out[seq_len(n)], as.data.frame, stringsAsFactors = FALSE))
  rownames(df) <- NULL
  df
}
