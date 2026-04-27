% tinyrox says don't edit this manually, but it can't stop you!
\name{instantiate_todo}
\alias{instantiate_todo}
\title{Create a hacer project layout in a Git repo.}
\usage{
instantiate_todo(repo_dir, syncthing_live_dir = NULL, overwrite = FALSE,
                 preview = .preview_default())
}
\arguments{
\item{repo_dir}{Path to your ToDo repo directory.}

\item{syncthing_live_dir}{Optional path to a Syncthing-shared live directory.}

\item{overwrite}{Overwrite existing files? Default `FALSE`.}

\item{preview}{If `TRUE`, return a `hacer_preview` instead of writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\description{
Create a hacer project layout in a Git repo.
}
