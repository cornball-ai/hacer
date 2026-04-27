% tinyrox says don't edit this manually, but it can't stop you!
\name{next_day}
\alias{next_day}
\title{Advance tasks from today to tomorrow within the Daily file}
\usage{
next_day(date = Sys.Date(), cfg = todo_config(), preview = .preview_default())
}
\arguments{
\item{date}{A Date. Defaults to `Sys.Date()`.}

\item{cfg}{A config list from `todo_config()`.}

\item{preview}{If `TRUE`, return a `hacer_preview` instead of writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\description{
Copies tasks from today's section to tomorrow's section (except completed
items and daily recurring like Email/ToDo if marked done). Then removes
unchecked items from today, keeping only in-progress and completed tasks
as a record of what was actually worked on.
}
