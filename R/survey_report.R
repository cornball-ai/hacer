# R/survey_report.R
# Markdown rendering of a survey() frame, one section per project.

#' Render a survey as markdown
#'
#' Groups the rows of [survey()] by project and writes one section per
#' project, most urgent first, so the todo items, git state, open pull
#' requests and note items for one piece of work read together. Project
#' names are matched ignoring case, spaces and punctuation, so
#' `Lil Casey` in the todo file, the `LilCasey` repo and the `lilcasey`
#' notes folder share a section.
#'
#' @param x A data.frame from [survey()].
#' @param max_items Lines per project before the rest folds into an
#'   "and N more" line.
#' @param date Date for the title.
#' @return A character vector of markdown lines. Show it with
#'   `writeLines()`.
#' @export
survey_report <- function(x = survey(), max_items = 12L, date = Sys.Date()) {
  title <- sprintf("# Survey %s", format(as.Date(date)))
  if (!nrow(x)) return(c(title, "", "Nothing to report."))
  key <- .project_key(x$project)
  src_rank <- match(x$source, c("todo", "git", "github", "tasks"))
  best <- tapply(x$priority, key, min)
  latest <- tapply(as.numeric(x$updated), key, .max_or_inf)
  keys <- names(best)[order(best, -latest[names(best)], names(best))]
  out <- title
  for (k in keys) {
    sel <- key == k
    rows <- x[sel, , drop = FALSE]
    rows <- rows[order(rows$priority, src_rank[sel]), , drop = FALSE]
    out <- c(out, "",
             sprintf("## %s (%s)", .project_name(rows),
                     c("attention", "in flight", "idle")[best[[k]]]),
             .report_lines(rows, max_items))
  }
  out
}

.max_or_inf <- function(v) if (all(is.na(v))) -Inf else max(v, na.rm = TRUE)

# Lowercase alphanumerics, so names agree across sources.
.project_key <- function(x) gsub("[^a-z0-9]", "", tolower(x))

# Display name: the repo's spelling when git saw it, else the first row.
.project_name <- function(rows) {
  pref <- order(match(rows$source, c("git", "github", "todo", "tasks")))
  rows$project[pref][1]
}

.report_lines <- function(rows, max_items) {
  marker <- c(important = "[!]", in_progress = "[/]", blocked = "[ ]",
              todo = "[ ]")
  lines <- character(nrow(rows))
  for (i in seq_len(nrow(rows))) {
    r <- rows[i, ]
    lines[i] <- switch(
      r$source,
      todo = sprintf("- %s %s", marker[[r$signal]], r$detail),
      git = sprintf("- git: %s", r$detail),
      github = sprintf("- %s <%s>", r$detail, r$path),
      tasks = if (identical(r$signal, "changed")) {
        sprintf("- note: %s", r$detail)
      } else {
        sprintf("- %s %s (%s)", marker[[r$signal]], r$detail,
                file.path(basename(dirname(r$path)), basename(r$path)))
      },
      sprintf("- %s: %s", r$source, r$detail)
    )
  }
  if (length(lines) > max_items) {
    lines <- c(lines[seq_len(max_items)],
               sprintf("- and %d more", length(lines) - max_items))
  }
  lines
}
