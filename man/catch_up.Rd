% tinyrox says don't edit this manually, but it can't stop you!
\name{catch_up}
\alias{catch_up}
\title{Catch a todo repo up to the current week}
\usage{
catch_up(date = Sys.Date(), cfg = todo_config(), preview = .preview_default())
}
\arguments{
\item{date}{Date to catch up to. Defaults to today.}

\item{cfg}{Config list from \code{todo_config()}.}

\item{preview}{If TRUE, report planned roll dates without writing.}
}
\value{
Character vector of Monday dates rolled, invisibly.
}
\description{
Rolls missing Monday files forward from the latest live/archive week to
the week containing \code{date}. This is intentionally conservative: it
creates missing week files but does not edit daily sections inside the
current week.
}
