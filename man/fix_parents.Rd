% tinyrox says don't edit this manually, but it can't stop you!
\name{fix_parents}
\alias{fix_parents}
\title{Roll up parent statuses in a single file}
\usage{
fix_parents(file_name, preview = .preview_default())
}
\arguments{
\item{file_name}{Path to a ToDo `.txt` file.}

\item{preview}{If `TRUE`, return a `hacer_preview` instead of writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\description{
Roll up parent statuses in a single file
}
