% tinyrox says don't edit this manually, but it can't stop you!
\name{parse_todo}
\alias{parse_todo}
\title{Parse a ToDo `.txt` file into a data.frame}
\usage{
parse_todo(file, period = NA_character_, indent = NULL)
}
\arguments{
\item{file}{Path to a ToDo `.txt` file.}

\item{period}{One of "Daily", "Week", "Month", "Quarter", or `NA`.}

\item{indent}{Spaces per indent level. Defaults to `todo_config()$indent`.}
}
\description{
Returns a data.frame with columns: id, parent_id, period, section, name,
recur, status, level, order, path.
}
