% tinyrox says don't edit this manually, but it can't stop you!
\name{advance_period}
\alias{advance_period}
\title{Advance four parsed period tables across a week boundary}
\usage{
advance_period(daily, week, month, quarter, prev_monday, next_monday)
}
\arguments{
\item{daily}{A parsed Daily data.frame.}

\item{week}{A parsed Week data.frame.}

\item{month}{A parsed Month data.frame.}

\item{quarter}{A parsed Quarter data.frame.}

\item{prev_monday}{A Date: the Monday just ended.}

\item{next_monday}{A Date: the new Monday being generated.}
}
\description{
Advance four parsed period tables across a week boundary
}
