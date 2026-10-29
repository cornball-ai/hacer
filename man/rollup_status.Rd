% tinyrox says don't edit this manually, but it can't stop you!
\name{rollup_status}
\alias{rollup_status}
\title{Roll child statuses up to parent tasks}
\usage{
rollup_status(df)
}
\arguments{
\item{df}{A parsed ToDo data.frame.}
}
\description{
A parent is `x` when every child is `x`, `/` when any child is `/` or
`x`, and blank otherwise. `[!]` (important) is a marker on the item
itself: an important child counts as open for its parent, and an
important parent keeps its marker until all of its children are done.
}
