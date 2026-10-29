% tinyrox says don't edit this manually, but it can't stop you!
\name{snapshot}
\alias{snapshot}
\title{Snapshot the live todo file}
\usage{
snapshot(
  date = Sys.Date() - 1L,
  cfg = todo_config(),
  overwrite = FALSE,
  archive = TRUE,
  before = .monday_of(Sys.Date()),
  commit = FALSE,
  push = FALSE,
  preview = .preview_default()
)
}
\arguments{
\item{date}{The day the snapshot captures. Defaults to yesterday.}

\item{cfg}{A config list from `todo_config()`.}

\item{overwrite}{If `TRUE`, replace an existing dated file.}

\item{archive}{If `TRUE` (default), sweep dated files older than
`before` into `cfg$archive_dir`.}

\item{before}{Cutoff for the sweep. Defaults to this week's Monday.}

\item{commit}{If `TRUE`, commit the swept files; see [archive_old()].}

\item{push}{If `TRUE` (and `commit`), push after committing.}

\item{preview}{If `TRUE`, return a `hacer_preview` instead of writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\value{
The snapshot path, invisibly, or a `hacer_preview`.
}
\description{
Copies `todo.md` to `todo_yymmdd.md` in `live_dir`, dated the day it
captures, then (by default) moves dated files from before this week into
the archive with [archive_old()]. Meant for an early-morning timer, so
the default `date` is yesterday: a run at 2am on Oct 29 writes
`todo_261028.md`. An existing dated file is left alone unless
`overwrite = TRUE`.
}
