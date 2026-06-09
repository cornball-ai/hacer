% tinyrox says don't edit this manually, but it can't stop you!
\name{tasks}
\alias{tasks}
\title{Read tasks as a structured data.frame}
\usage{
tasks(file = NULL, status = NULL, recurring = NULL, blocked = NULL,
      cfg = todo_config())
}
\arguments{
\item{file}{Path to a single file, a character vector of paths, or `NULL`
(default) to parse every `ToDo_*.txt` in `cfg$live_dir`.}

\item{status}{Optional filter. One or more of `"todo"`, `"in_progress"`,
`"done"`, `"blocked"`.}

\item{recurring}{Optional logical filter. Keep only recurring (`TRUE`) or
non-recurring (`FALSE`) tasks.}

\item{blocked}{Optional logical filter. Convenience for
`status = "blocked"`. Combines (intersects) with `status` if both given.}

\item{cfg}{Config list from [todo_config()]. Used to resolve `live_dir`
and `indent` when `file = NULL`.}
}
\value{
A `data.frame` with columns:
\describe{
  \item{id}{character, ephemeral, derived from file basename and line number}
  \item{file}{character, source file basename (not full path)}
  \item{line}{integer, 1-indexed line number in the source file}
  \item{depth}{integer, 0 = root, +1 per indent level}
  \item{status}{character, one of `"todo"`, `"in_progress"`, `"done"`, `"blocked"`}
  \item{recurring}{logical, `TRUE` if the task has the `*` prefix}
  \item{text}{character, task text with status brackets and `-`/`*` prefixes stripped}
  \item{parent_id}{character, `id` of nearest ancestor with lower depth, or `NA` for root tasks}
}
}
\description{
Parses one or more ToDo files into a `data.frame` so agents and ad-hoc R
sessions can filter and reason about tasks without re-parsing text.
}
\details{
IDs are ephemeral: deterministic for a given parse, but they shift when
lines are inserted or removed. Don't persist them across edits.

}
