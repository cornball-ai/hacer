% tinyrox says don't edit this manually, but it can't stop you!
\name{archive_old}
\alias{archive_old}
\title{Move dated todo files from before a cutoff into the archive}
\usage{
archive_old(
  cfg = todo_config(),
  before = .monday_of(Sys.Date()),
  commit = FALSE,
  push = FALSE,
  preview = .preview_default()
)
}
\arguments{
\item{cfg}{A config list from `todo_config()`.}

\item{before}{A Date. Files dated before it are archived. Defaults to
this week's Monday.}

\item{commit}{If `TRUE`, commit the moved files to the archive's repo.}

\item{push}{If `TRUE` (and `commit`), push after committing.}

\item{preview}{If `TRUE`, report the moves without touching anything.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\value{
A data.frame of moves (`from`, `to`), invisibly, or a
  `hacer_preview` whose `files_moved` lists them.
}
\description{
Looks in `cfg$live_dir` for dated files (`todo_yymmdd.md` snapshots and
the older `todo_yymmdd_<period>` forms) dated before `before` and moves
them to `cfg$archive_dir`. When the archive already has a file of that
name, the live copy is removed if the two are identical and left in
place with a warning otherwise.
}
\details{
With `commit = TRUE`, the moved files are staged and committed in the
git repository that contains `archive_dir`. Only those paths are staged.
Nothing is committed when the archive isn't inside a repository.

}
