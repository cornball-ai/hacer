% tinyrox says don't edit this manually, but it can't stop you!
\name{todo_config}
\alias{todo_config}
\title{Load the ToDo repo configuration}
\usage{
todo_config(repo_dir = .default_repo_dir())
}
\arguments{
\item{repo_dir}{Path to your ToDo repo directory.}
}
\description{
Resolution order for `repo_dir`:
1. The argument if supplied.
2. `options("hacer.repo")` (set by `use_repo()` within a session).
3. The `HACER_REPO` environment variable (for one-shot CLI invocations
like `HACER_REPO=~/todo r -e 'hacer::run_monday()'`).
4. `tools::R_user_dir("hacer", "data")` (CRAN-safe fallback; ugly path,
so users typically instantiate at `~/todo` and set the option or env
var instead).
}
