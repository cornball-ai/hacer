% tinyrox says don't edit this manually, but it can't stop you!
\name{check_setup}
\alias{check_setup}
\title{Quick check that repo is wired correctly}
\usage{
check_setup(repo_dir = NULL)
}
\arguments{
\item{repo_dir}{Path to your ToDo repo directory. If `NULL`, falls back
through the standard resolution order.}
}
\description{
Uses the same `repo_dir` resolution as [todo_config()] (arg > option >
`HACER_REPO` env var > working directory).
}
