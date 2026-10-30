# R/survey.R
# Deterministic ranking of ongoing work from the todo file, local git repos,
# open GitHub pull requests and a notes directory. Returns a data.frame;
# presentation (a morning post, a console glance) is the caller's business.

#' Survey ongoing work
#'
#' Collects signals from four sources and ranks them: priority 1 needs
#' attention now, 2 is in flight, 3 is on the list but idle.
#'
#' \describe{
#'   \item{todo}{Open items in the live todo file. `[!]` and `#blocked`
#'     are 1, `[/]` is 2, `[ ]` is 3. Done items are skipped.}
#'   \item{git}{Repos directly under `root` (or the given `repos`) whose
#'     `origin` belongs to one of `owners`. A dirty worktree on an active
#'     repo (commits in the window, or a commit in the last 14 days) is 1.
#'     Commits in the window and branches ahead of their upstream are 2.
#'     A dirty worktree on a dormant repo is 3. Repos without a commit
#'     history are skipped.}
#'   \item{github}{Open pull requests in the `owners`' repositories, via
#'     the `gh` CLI. Priority 2.}
#'   \item{tasks}{Notes under `tasks_dir`. A `.md` file modified in the
#'     window gives a `changed` row at 2. Every open task-list item in
#'     any note (fenced code skipped) gives a row ranked like a todo
#'     item: `[!]` and `#blocked` are 1, `[/]` is 2, an open `[ ]` is 2
#'     in a note changed within the window and 3 in an older one. The
#'     project is the note's first folder under `tasks_dir`.}
#' }
#'
#' [survey_report()] renders the result as markdown, one section per
#' project.
#'
#' @param cfg A config list from `todo_config()`.
#' @param todo Path to the todo file. Defaults to [todo_file()]. Skipped
#'   when missing.
#' @param root Directory whose immediate subdirectories are scanned for
#'   git repos. Ignored when `repos` is given.
#' @param repos Explicit repo directories to scan instead of `root`.
#' @param owners GitHub owners (users or orgs) whose repos count as yours.
#'   Defaults to `options("hacer.survey_owners")`, then the
#'   `HACER_SURVEY_OWNERS` env var (comma separated). `NULL` keeps every
#'   repo with a commit history and skips the GitHub query.
#' @param tasks_dir Directory of notes to watch for recent changes.
#'   Defaults to `options("hacer.tasks_dir")`, then `HACER_TASKS_DIR`.
#'   `NULL` skips it.
#' @param days Window, in days, for commits, note changes and the
#'   active-repo test.
#' @param github If `TRUE`, query open PRs with `gh`. Skipped when
#'   `owners` is `NULL` or `gh` isn't on the path.
#' @return A data.frame sorted by priority with columns `priority`
#'   (integer 1-3), `source` (`"todo"`, `"git"`, `"github"`, `"tasks"`),
#'   `project`, `signal`, `detail`, `path` and `updated` (POSIXct, `NA`
#'   when unknown).
#' @export
survey <- function(cfg = todo_config(), todo = todo_file(cfg),
                   root = "~", repos = NULL,
                   owners = .survey_owners(), tasks_dir = .tasks_dir(),
                   days = 3L, github = TRUE) {
  indent <- if (!is.null(cfg$indent)) as.integer(cfg$indent) else 2L
  rows <- list(
    .empty_survey_df(),
    .survey_todo(todo, indent),
    .survey_git(repos, root, owners, days),
    if (github) .survey_github(owners) else NULL,
    .survey_tasks(tasks_dir, days, indent)
  )
  out <- do.call(rbind, rows)
  src_rank <- match(out$source, c("todo", "git", "github", "tasks"))
  out <- out[order(out$priority, src_rank, out$project, out$detail), ,
             drop = FALSE]
  rownames(out) <- NULL
  out
}

.empty_survey_df <- function() {
  data.frame(priority = integer(), source = character(),
             project = character(), signal = character(),
             detail = character(), path = character(),
             updated = .POSIXct(numeric()), stringsAsFactors = FALSE)
}

.survey_rows <- function(priority, source, project, signal, detail, path,
                         updated = NA) {
  if (!length(project)) return(NULL)
  if (!inherits(updated, "POSIXct")) {
    updated <- .POSIXct(rep(NA_real_, length(project)))
  }
  data.frame(priority = as.integer(priority), source = source,
             project = project, signal = signal, detail = detail,
             path = path, updated = updated, stringsAsFactors = FALSE)
}

.survey_todo <- function(todo, indent = 2L) {
  if (is.null(todo) || !file.exists(todo)) return(NULL)
  df <- parse_todo(todo, indent = indent)
  df <- df[df$status != "x", , drop = FALSE]
  if (!nrow(df)) return(NULL)
  rank <- .rank_items(df$status, df$name)
  project <- vapply(strsplit(df$path, " > ", fixed = TRUE), `[[`, "", 1L)
  .survey_rows(rank$priority, "todo", project, rank$signal, df$path, todo,
               rep(file.mtime(todo), nrow(df)))
}

# Priority and signal for open items. `[!]` and `#blocked` are 1, `[/]`
# is 2, and a plain open item takes `open_priority`.
.rank_items <- function(status, name, open_priority = 3L) {
  blocked <- .is_blocked(name)
  list(
    priority = ifelse(status == "!" | blocked, 1L,
                      ifelse(status == "/", 2L, as.integer(open_priority))),
    signal = ifelse(blocked, "blocked",
                    ifelse(status == "!", "important",
                           ifelse(status == "/", "in_progress", "todo")))
  )
}

.survey_git <- function(repos, root, owners, days) {
  if (is.null(repos)) {
    dirs <- list.dirs(path.expand(root), recursive = FALSE)
    dirs <- dirs[!startsWith(basename(dirs), ".")]
    repos <- dirs[file.exists(file.path(dirs, ".git"))]
  } else {
    repos <- path.expand(repos)
  }
  if (!length(repos)) return(NULL)
  do.call(rbind, lapply(repos, .survey_repo, owners = owners, days = days))
}

# Owner segment of a remote URL: git@host:owner/repo.git or
# https://host/owner/repo(.git).
.remote_owner <- function(url) {
  parts <- strsplit(sub("\\.git$", "", url), "[/:]")[[1]]
  parts <- parts[nzchar(parts)]
  if (length(parts) < 2L) return(NA_character_)
  parts[length(parts) - 1L]
}

.survey_repo <- function(repo, owners, days) {
  if (!is.null(owners)) {
    url <- .git(repo, "remote", "get-url", "origin")
    if (.git_failed(url) || !length(url)) return(NULL)
    if (!(.remote_owner(url[1]) %in% owners)) return(NULL)
  }
  last <- .git(repo, "log", "-1", "--format=%ct")
  if (.git_failed(last) || !length(last)) return(NULL)
  last_ct <- .POSIXct(as.numeric(last[1]))
  age <- as.numeric(difftime(Sys.time(), last_ct, units = "days"))
  name <- basename(repo)
  rows <- list()

  subjects <- .git(repo, "log",
                   sprintf("--since=%d.days.ago", as.integer(days)),
                   "--format=%s")
  n_commits <- if (.git_failed(subjects)) 0L else length(subjects)
  if (n_commits) {
    latest <- paste(subjects[seq_len(min(3L, n_commits))], collapse = " | ")
    rows[[length(rows) + 1L]] <- .survey_rows(
      2L, "git", name, "commits",
      sprintf("%d commit%s in %d days, latest: %s", n_commits,
              if (n_commits == 1L) "" else "s", as.integer(days), latest),
      repo, last_ct)
  }

  dirty <- .git(repo, "status", "--porcelain")
  n_dirty <- if (.git_failed(dirty)) 0L else length(dirty)
  if (n_dirty) {
    active <- n_commits > 0L || age <= 14
    rows[[length(rows) + 1L]] <- .survey_rows(
      if (active) 1L else 3L, "git", name, "dirty",
      sprintf("%d uncommitted path%s, last commit %d days ago", n_dirty,
              if (n_dirty == 1L) "" else "s", as.integer(age)),
      repo, last_ct)
  }

  ahead <- .survey_ahead(repo)
  if (length(ahead)) {
    rows[[length(rows) + 1L]] <- .survey_rows(
      2L, "git", name, "unpushed", ahead, repo, last_ct)
  }
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

# One line per local branch that is ahead of its upstream, plus the checked
# out branch when it has no upstream at all.
.survey_ahead <- function(repo) {
  fmt <- "%(refname:short)%09%(upstream:short)%09%(upstream:track)"
  refs <- .git(repo, "for-each-ref", paste0("--format=", shQuote(fmt)),
               "refs/heads")
  if (.git_failed(refs) || !length(refs)) return(character())
  head <- .git(repo, "symbolic-ref", "--short", "HEAD")
  head <- if (.git_failed(head) || !length(head)) "" else head[1]
  out <- character()
  for (ln in refs) {
    f <- strsplit(ln, "\t", fixed = TRUE)[[1]]
    branch <- f[1]
    upstream <- if (length(f) >= 2L) f[2] else ""
    track <- if (length(f) >= 3L) f[3] else ""
    m <- regmatches(track, regexec("ahead ([0-9]+)", track))[[1]]
    if (length(m) == 2L) {
      out <- c(out, sprintf("%s is %s commit%s ahead of %s", branch, m[2],
                            if (m[2] == "1") "" else "s", upstream))
    } else if (!nzchar(upstream) && identical(branch, head)) {
      out <- c(out, sprintf("%s has no upstream", branch))
    }
  }
  out
}

.survey_github <- function(owners) {
  if (is.null(owners) || !nzchar(Sys.which("gh"))) return(NULL)
  jq <- paste(".[] | [.repository.nameWithOwner, .number, .updatedAt,",
              ".author.login, .title] | @tsv")
  args <- c("search", "prs", "--state", "open", "--limit", "100",
            as.vector(rbind("--owner", owners)),
            "--json", "repository,number,title,updatedAt,author",
            "--jq", shQuote(jq))
  out <- suppressWarnings(system2("gh", args, stdout = TRUE, stderr = FALSE))
  if (!is.null(attr(out, "status")) || !length(out)) return(NULL)
  f <- strsplit(out, "\t", fixed = TRUE)
  f <- f[lengths(f) >= 5L]
  if (!length(f)) return(NULL)
  full  <- vapply(f, `[[`, "", 1L)
  num   <- vapply(f, `[[`, "", 2L)
  upd   <- vapply(f, `[[`, "", 3L)
  auth  <- vapply(f, `[[`, "", 4L)
  title <- vapply(f, function(x) paste(x[-(1:4)], collapse = " "), "")
  updated <- as.POSIXct(upd, format = "%Y-%m-%dT%H:%M:%SZ", tz = "UTC")
  .survey_rows(2L, "github", sub("^.*/", "", full), "open_pr",
               sprintf("PR #%s by %s: %s", num, auth, title),
               sprintf("https://github.com/%s/pull/%s", full, num), updated)
}

.survey_tasks <- function(tasks_dir, days, indent = 2L) {
  if (is.null(tasks_dir)) return(NULL)
  tasks_dir <- path.expand(tasks_dir)
  if (!dir.exists(tasks_dir)) return(NULL)
  files <- list.files(tasks_dir, pattern = "\\.md$", recursive = TRUE,
                      full.names = TRUE)
  if (!length(files)) return(NULL)
  mtime <- file.mtime(files)
  recent <- mtime >= Sys.time() - as.numeric(days) * 86400
  rel <- substring(files, nchar(tasks_dir) + 2L)
  project <- ifelse(grepl("/", rel, fixed = TRUE),
                    sub("/.*$", "", rel), basename(tasks_dir))
  changed <- if (any(recent)) {
    .survey_rows(2L, "tasks", project[recent], "changed",
                 sprintf("%s changed %s", rel[recent],
                         format(mtime[recent], "%Y-%m-%d %H:%M")),
                 files[recent], mtime[recent])
  }
  items <- Map(.survey_note_items, files, project, recent, as.numeric(mtime),
               MoreArgs = list(indent = indent))
  rows <- do.call(rbind, c(list(changed), unname(items)))
  if (is.null(rows) || !nrow(rows)) return(NULL)
  rows
}

# One row per open task-list item in a note. An open [ ] is in flight
# when the note changed within the window, on the list otherwise.
.survey_note_items <- function(file, project, recent, mtime, indent = 2L) {
  items <- .task_items(readLines(file, warn = FALSE), indent)
  items <- items[items$status != "x", , drop = FALSE]
  if (!nrow(items)) return(NULL)
  rank <- .rank_items(items$status, items$name,
                      open_priority = if (recent) 2L else 3L)
  .survey_rows(rank$priority, "tasks", project, rank$signal, items$name,
               file, rep(.POSIXct(mtime), nrow(items)))
}

# Task-list lines outside fenced code blocks, as status and name. Notes
# have no recurring marker, so a leading `*` is markdown emphasis.
.task_items <- function(lines, indent = 2L) {
  fenced <- cumsum(grepl("^\\s*(```|~~~)", lines)) %% 2L == 1L
  status <- character()
  name <- character()
  for (ln in lines[!fenced]) {
    p <- .parse_task_line(ln, indent, recur_marker = FALSE)
    if (is.null(p)) next
    status <- c(status, p$status)
    name <- c(name, p$name)
  }
  data.frame(status = status, name = name, stringsAsFactors = FALSE)
}
