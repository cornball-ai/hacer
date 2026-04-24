% tinyrox says don't edit this manually, but it can't stop you!
\name{roll_day}
\alias{roll_day}
\title{Roll the most recent ToDo files forward to today}
\usage{
roll_day(date = Sys.Date(), cfg = todo_config())
}
\arguments{
\item{date}{A Date. Defaults to \code{Sys.Date()}.}

\item{cfg}{A config list from \code{todo_config()}.}
}
\description{
Finds the most recent file of each cadence in \code{this_week/}, copies it
forward to \code{today}, strips completed non-recurring items, resets
recurring done items to blank, and appends dropped items to
\code{<repo>/done.log}.
}
