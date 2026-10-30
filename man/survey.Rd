% tinyrox says don't edit this manually, but it can't stop you!
\name{survey}
\alias{survey}
\title{Survey ongoing work}
\usage{
survey(
  cfg = todo_config(),
  todo = todo_file(cfg),
  root = "~",
  repos = NULL,
  owners = .survey_owners(),
  tasks_dir = .tasks_dir(),
  days = 3L,
  github = TRUE
)
}
\arguments{
\item{cfg}{A config list from `todo_config()`.}

\item{todo}{Path to the todo file. Defaults to [todo_file()]. Skipped
when missing.}

\item{root}{Directory whose immediate subdirectories are scanned for
git repos. Ignored when `repos` is given.}

\item{repos}{Explicit repo directories to scan instead of `root`.}

\item{owners}{GitHub owners (users or orgs) whose repos count as yours.
Defaults to `options("hacer.survey_owners")`, then the
`HACER_SURVEY_OWNERS` env var (comma separated). `NULL` keeps every
repo with a commit history and skips the GitHub query.}

\item{tasks_dir}{Directory of notes to watch for recent changes.
Defaults to `options("hacer.tasks_dir")`, then `HACER_TASKS_DIR`.
`NULL` skips it.}

\item{days}{Window, in days, for commits, note changes and the
active-repo test.}

\item{github}{If `TRUE`, query open PRs with `gh`. Skipped when
`owners` is `NULL` or `gh` isn't on the path.}
}
\value{
A data.frame sorted by priority with columns `priority`
  (integer 1-3), `source` (`"todo"`, `"git"`, `"github"`, `"tasks"`),
  `project`, `signal`, `detail`, `path` and `updated` (POSIXct, `NA`
  when unknown).
}
\description{
Collects signals from four sources and ranks them: priority 1 needs
attention now, 2 is in flight, 3 is on the list but idle.
}
\details{
\describe{
\item{todo}{Open items in the live todo file. A top-level item names
the project and its descendants are the tasks, so a top-level item
with open children is not itself a row unless it carries `[!]` or
`#blocked`; one with no open children is its own task. `detail` is
the task's path below the project. `[!]` and `#blocked` are 1,
`[/]` is 2, `[ ]` is 3. Done items are skipped.}
\item{git}{Repos directly under `root` (or the given `repos`) whose
`origin` belongs to one of `owners`. A dirty worktree on an active
repo (commits in the window, or a commit in the last 14 days) is 1.
Commits in the window and branches ahead of their upstream are 2.
A dirty worktree on a dormant repo is 3. Repos without a commit
history are skipped.}
\item{github}{Open pull requests in the `owners`' repositories, via
the `gh` CLI. Priority 2.}
\item{tasks}{Notes under `tasks_dir`. A `.md` file modified in the
window gives a `changed` row at 2. Every open task-list item in
any note (fenced code skipped) gives a row ranked like a todo
item: `[!]` and `#blocked` are 1, `[/]` is 2, an open `[ ]` is 2
in a note changed within the window and 3 in an older one. The
project is the note's first folder under `tasks_dir`.}
}

[survey_report()] renders the result as markdown, one section per
project.

}
