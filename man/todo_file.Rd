% tinyrox says don't edit this manually, but it can't stop you!
\name{todo_file}
\alias{todo_file}
\title{Path to the live todo file}
\usage{
todo_file(cfg = todo_config())
}
\arguments{
\item{cfg}{A config list from `todo_config()`.}
}
\value{
The path `<live_dir>/todo.md`. The file need not exist.
}
\description{
The single-file workflow keeps one hand-edited `todo.md` in `live_dir`.
[snapshot()] copies it to a dated file each day and [survey()] reads it.
}
