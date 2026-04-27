% tinyrox says don't edit this manually, but it can't stop you!
\name{sync_from_daily}
\alias{sync_from_daily}
\title{Sync new items added in Daily up to Week/Month/Quarter}
\usage{
sync_from_daily(date = Sys.Date(), cfg = todo_config(),
                preview = .preview_default())
}
\arguments{
\item{date}{A Date. Defaults to `Sys.Date()`.}

\item{cfg}{A config list from `todo_config()`.}

\item{preview}{If `TRUE`, return a `hacer_preview` instead of writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\description{
Sync new items added in Daily up to Week/Month/Quarter
}
