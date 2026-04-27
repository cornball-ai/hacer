% tinyrox says don't edit this manually, but it can't stop you!
\name{read_recurring}
\alias{read_recurring}
\title{Read a recurring-task manifest}
\usage{
read_recurring(path)
}
\arguments{
\item{path}{Path to a `recurring.txt` file.}
}
\value{
A `data.frame` with columns `freq`, `days` (list-column of int
  vectors), `week_of_month` (int or `NA`), `path`, `name`, `parent_path`,
  `level`, `order`.
}
\description{
Read a recurring-task manifest
}
