# R/tasks.R
#' Read tasks as a structured data.frame
#'
#' Parses one or more ToDo files into a `data.frame` so agents and ad-hoc R
#' sessions can filter and reason about tasks without re-parsing text.
#'
#' IDs are ephemeral: deterministic for a given parse, but they shift when
#' lines are inserted or removed. Don't persist them across edits.
#'
#' @param file Path to a single file, a character vector of paths, or `NULL`
#'   (default) to parse every `ToDo_*.txt` in `cfg$live_dir`.
#' @param status Optional filter. One or more of `"todo"`, `"in_progress"`,
#'   `"done"`, `"blocked"`.
#' @param recurring Optional logical filter. Keep only recurring (`TRUE`) or
#'   non-recurring (`FALSE`) tasks.
#' @param blocked Optional logical filter. Convenience for
#'   `status = "blocked"`. Combines (intersects) with `status` if both given.
#' @param cfg Config list from [todo_config()]. Used to resolve `live_dir`
#'   and `indent` when `file = NULL`.
#'
#' @return A `data.frame` with columns:
#' \describe{
#'   \item{id}{character, ephemeral, derived from file basename and line number}
#'   \item{file}{character, source file basename (not full path)}
#'   \item{line}{integer, 1-indexed line number in the source file}
#'   \item{depth}{integer, 0 = root, +1 per indent level}
#'   \item{status}{character, one of `"todo"`, `"in_progress"`, `"done"`, `"blocked"`}
#'   \item{recurring}{logical, `TRUE` if the task has the `*` prefix}
#'   \item{text}{character, task text with status brackets and `-`/`*` prefixes stripped}
#'   \item{parent_id}{character, `id` of nearest ancestor with lower depth, or `NA` for root tasks}
#' }
#' @export
tasks <- function(file = NULL,
                  status = NULL,
                  recurring = NULL,
                  blocked = NULL,
                  cfg = todo_config()) {
  files <- if (is.null(file)) {
    list.files(cfg$live_dir,
               pattern = "^todo_\\d{6}_.+\\.(md|txt)$",
               full.names = TRUE,
               ignore.case = TRUE)
  } else {
    nm <- path.expand(file)
    miss <- nm[!file.exists(nm)]
    if (length(miss)) stop("File(s) not found: ", paste(miss, collapse = ", "))
    nm
  }

  if (!length(files)) return(.empty_tasks_df())

  indent <- if (!is.null(cfg$indent)) as.integer(cfg$indent) else 2L
  rows <- lapply(files, .lex_tasks, indent = indent)
  df <- do.call(rbind, rows)
  if (is.null(df) || !nrow(df)) df <- .empty_tasks_df()

  if (!is.null(status))    df <- df[df$status %in% status, , drop = FALSE]
  if (!is.null(recurring)) df <- df[df$recurring %in% recurring, , drop = FALSE]
  if (!is.null(blocked))   df <- df[(df$status == "blocked") == blocked, , drop = FALSE]

  rownames(df) <- NULL
  df
}

.empty_tasks_df <- function() {
  data.frame(
    id        = character(),
    file      = character(),
    line      = integer(),
    depth     = integer(),
    status    = character(),
    recurring = logical(),
    text      = character(),
    parent_id = character(),
    stringsAsFactors = FALSE
  )
}

# Internal: parse one file into a tasks() row set.
.lex_tasks <- function(path, indent = 2L) {
  lines <- readLines(path, warn = FALSE)
  basenm <- basename(path)
  if (!length(lines)) return(.empty_tasks_df())

  status_map <- c(" " = "todo", "/" = "in_progress",
                  "x" = "done", "!" = "blocked")

  is_task    <- logical(length(lines))
  raw_status <- character(length(lines))
  raw_recur  <- logical(length(lines))
  raw_depth  <- integer(length(lines))
  raw_text   <- character(length(lines))

  for (i in seq_along(lines)) {
    parsed <- .parse_task_line(lines[[i]], indent)
    if (is.null(parsed)) next
    is_task[i]    <- TRUE
    raw_depth[i]  <- parsed$level
    raw_status[i] <- parsed$status
    raw_recur[i]  <- parsed$recur
    raw_text[i]   <- parsed$name
  }

  if (!any(is_task)) return(.empty_tasks_df())

  idx <- which(is_task)
  n <- length(idx)

  ids <- paste0(basenm, ":L", idx)
  parents <- character(n)
  stack_id <- character(64L)

  for (k in seq_len(n)) {
    d <- raw_depth[idx[k]]
    if (d == 0L) {
      parents[k] <- NA_character_
    } else if (d <= length(stack_id) && nzchar(stack_id[d])) {
      parents[k] <- stack_id[d]
    } else {
      parents[k] <- NA_character_
    }
    slot <- d + 1L
    if (slot > length(stack_id)) {
      stack_id <- c(stack_id, character(slot - length(stack_id)))
    }
    stack_id[slot] <- ids[k]
    if (slot < length(stack_id)) {
      stack_id[(slot + 1L):length(stack_id)] <- ""
    }
  }

  data.frame(
    id        = ids,
    file      = basenm,
    line      = idx,
    depth     = raw_depth[idx],
    status    = unname(status_map[raw_status[idx]]),
    recurring = raw_recur[idx],
    text      = raw_text[idx],
    parent_id = parents,
    stringsAsFactors = FALSE
  )
}
