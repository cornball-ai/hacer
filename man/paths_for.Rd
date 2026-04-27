% tinyrox says don't edit this manually, but it can't stop you!
\name{paths_for}
\alias{paths_for}
\title{File paths for a given week's ToDo files}
\usage{
paths_for(date = Sys.Date(), cfg = todo_config())
}
\arguments{
\item{date}{A Date. Defaults to `Sys.Date()`.}

\item{cfg}{A config list from `todo_config()`.}
}
\description{
Returns the canonical lowercase filenames. Pre-0.1.7 repos that still
have capitalized `ToDo_*.txt` files are still recognized by readers; new
writes always emit lowercase.
}
