% tinyrox says don't edit this manually, but it can't stop you!
\name{run_monday}
\alias{run_monday}
\title{Generate the new week's files (run on Mondays)}
\usage{
run_monday(date = Sys.Date(), cfg = todo_config(), preview = .preview_default())
}
\arguments{
\item{date}{A Date. Defaults to `Sys.Date()`.}

\item{cfg}{A config list from `todo_config()`.}

\item{preview}{If `TRUE`, return a `hacer_preview` instead of writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\description{
Generate the new week's files (run on Mondays)
}
