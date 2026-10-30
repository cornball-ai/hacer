# test_survey.R - survey() ranks todo, git and notes signals

library(hacer)

root <- tempfile("survey_root_")
dir.create(root, recursive = TRUE)

todo_repo <- file.path(root, "todo")
dir.create(file.path(todo_repo, "this_week"), recursive = TRUE)
cfg <- list(live_dir = file.path(todo_repo, "this_week"),
            archive_dir = file.path(todo_repo, "archive"),
            indent = 2L)
writeLines(c(
  "- [ ] Alpha",
  "  - [/] alpha step",
  "  - [x] alpha done",
  "- [!] Beta",
  "- [ ] Gamma #blocked on review",
  "- [x] Delta"
), hacer::todo_file(cfg))

tasks_dir <- file.path(root, "tasks")
dir.create(file.path(tasks_dir, "proj"), recursive = TRUE)
writeLines(c(
  "# handoff",
  "- [ ] next step one",
  "  - [/] sub in progress",
  "- [!] urgent thing",
  "- [x] already done",
  "- [ ] stuck on review #blocked",
  "- [ ] **bold** step",
  "```",
  "- [ ] not an item, it is in a code block",
  "```"
), file.path(tasks_dir, "proj", "handoff.md"))
writeLines(c("old note", "- [ ] stale item"),
           file.path(tasks_dir, "proj", "old.md"))
Sys.setFileTime(file.path(tasks_dir, "proj", "old.md"),
                Sys.time() - 30 * 86400)
writeLines("top", file.path(tasks_dir, "top.md"))
writeLines("not markdown", file.path(tasks_dir, "proj", "data.csv"))

# ---- Case 1: todo and notes signals, no git ----
s1 <- hacer::survey(cfg = cfg, repos = character(), tasks_dir = tasks_dir,
                    github = FALSE)
expect_equal(names(s1),
             c("priority", "source", "project", "signal", "detail", "path",
               "updated"),
             info = "column set")
expect_true(is.integer(s1$priority))
expect_inherits(s1$updated, "POSIXct")
expect_true(all(diff(s1$priority) >= 0), info = "sorted by priority")

todo1 <- s1[s1$source == "todo", ]
expect_equal(nrow(todo1), 4L, info = "done items are skipped")
expect_equal(todo1$signal[todo1$detail == "Beta"], "important")
expect_equal(todo1$priority[todo1$detail == "Beta"], 1L,
             info = "[!] ranks P1")
expect_equal(todo1$signal[grepl("Gamma", todo1$detail)], "blocked")
expect_equal(todo1$priority[grepl("Gamma", todo1$detail)], 1L,
             info = "#blocked ranks P1")
expect_equal(todo1$priority[todo1$detail == "Alpha > alpha step"], 2L,
             info = "[/] ranks P2")
expect_equal(todo1$project[todo1$detail == "Alpha > alpha step"], "Alpha",
             info = "project is the top-level ancestor")
expect_equal(todo1$priority[todo1$detail == "Alpha"], 3L,
             info = "open [ ] ranks P3")
expect_equal(unique(todo1$path), hacer::todo_file(cfg))

tk1 <- s1[s1$source == "tasks", ]
ch1 <- tk1[tk1$signal == "changed", ]
expect_equal(nrow(ch1), 2L, info = "only recent .md notes are listed as changed")
expect_equal(sort(ch1$project), c("proj", "tasks"),
             info = "project is the subfolder, or the dir name at top level")
expect_true(all(ch1$priority == 2L))
expect_false(any(grepl("old.md", ch1$detail)),
             info = "notes outside the window are not 'changed'")

it1 <- tk1[tk1$signal != "changed", ]
expect_equal(sort(it1$detail),
             sort(c("next step one", "sub in progress", "urgent thing",
                    "stuck on review #blocked", "**bold** step",
                    "stale item")),
             info = paste("open items from every note; done and fenced lines",
                          "skipped; a leading * is emphasis, not recurring"))
expect_equal(it1$priority[it1$detail == "urgent thing"], 1L)
expect_equal(it1$signal[it1$detail == "urgent thing"], "important")
expect_equal(it1$priority[grepl("stuck", it1$detail)], 1L)
expect_equal(it1$signal[grepl("stuck", it1$detail)], "blocked")
expect_equal(it1$priority[it1$detail == "sub in progress"], 2L)
expect_equal(it1$signal[it1$detail == "sub in progress"], "in_progress")
expect_equal(it1$priority[it1$detail == "next step one"], 2L,
             info = "open item in a recent note is in flight")
expect_equal(it1$priority[it1$detail == "stale item"], 3L,
             info = "open item in an old note is on the list")
expect_equal(unique(it1$project), "proj")
expect_true(all(basename(it1$path) %in% c("handoff.md", "old.md")))
expect_inherits(it1$updated, "POSIXct")

# Nothing configured: empty frame with the same columns
s_empty <- hacer::survey(cfg = list(live_dir = file.path(root, "nope"),
                                    indent = 2L),
                         repos = character(), tasks_dir = NULL,
                         github = FALSE)
expect_equal(nrow(s_empty), 0L)
expect_equal(names(s_empty), names(s1))

# ---- Report: one markdown section per project, most urgent first ----
rep1 <- hacer::survey_report(s1, date = as.Date("2026-10-29"))
expect_true(is.character(rep1))
expect_equal(rep1[1], "# Survey 2026-10-29")
expect_true(any(rep1 == "## proj (attention)"),
            info = "section labelled by the project's best priority")
expect_true(any(rep1 == "## Alpha (in flight)"))
expect_true(any(rep1 == "- [!] urgent thing (proj/handoff.md)"),
            info = "note items carry their marker and note")
expect_true(any(rep1 == "- [/] Alpha > alpha step"),
            info = "todo items carry their marker and path")
expect_true(any(grepl("^- note: proj/handoff.md changed ", rep1)))
expect_true(which(rep1 == "## proj (attention)") <
              which(rep1 == "## Alpha (in flight)"),
            info = "attention sections come before in-flight ones")
rep0 <- hacer::survey_report(s_empty)
expect_true(any(rep0 == "Nothing to report."))
expect_equal(hacer:::.project_key(c("Lil Casey", "LilCasey", "lilcasey")),
             rep("lilcasey", 3L),
             info = "project names match across sources")
rep_cap <- hacer::survey_report(s1, max_items = 1L)
expect_true(any(grepl("^- and [0-9]+ more$", rep_cap)),
            info = "long sections fold")

# Option and env var defaults resolve
op <- options(hacer.survey_owners = c("a", "b"), hacer.tasks_dir = "/x")
expect_equal(hacer:::.survey_owners(), c("a", "b"))
expect_equal(hacer:::.tasks_dir(), "/x")
options(hacer.survey_owners = NULL, hacer.tasks_dir = NULL)
Sys.setenv(HACER_SURVEY_OWNERS = "c, d", HACER_TASKS_DIR = "/y")
expect_equal(hacer:::.survey_owners(), c("c", "d"))
expect_equal(hacer:::.tasks_dir(), "/y")
Sys.unsetenv(c("HACER_SURVEY_OWNERS", "HACER_TASKS_DIR"))
expect_null(hacer:::.survey_owners())
expect_null(hacer:::.tasks_dir())
options(op)

# ---- Case 2: git signals ----
if (nzchar(Sys.which("git"))) {
  git_in <- function(repo, ..., env = character()) {
    suppressWarnings(system2("git", c("-C", shQuote(repo), ...), env = env,
                             stdout = TRUE, stderr = TRUE))
  }
  mk_repo <- function(name, origin = NULL, commit = TRUE) {
    d <- file.path(root, name)
    dir.create(d)
    git_in(d, "init", "-q")
    git_in(d, "config", "user.email", "t@example.com")
    git_in(d, "config", "user.name", "t")
    if (!is.null(origin)) git_in(d, "remote", "add", "origin", origin)
    if (commit) {
      writeLines("a", file.path(d, "a.txt"))
      git_in(d, "add", "a.txt")
      git_in(d, "commit", "-q", "-m", shQuote("First commit"))
    }
    d
  }

  active <- mk_repo("active", "git@github.com:acme/active.git")
  writeLines("b", file.path(active, "b.txt"))
  theirs <- mk_repo("theirs", "https://github.com/other/theirs.git")
  empty <- mk_repo("empty", "git@github.com:acme/empty.git", commit = FALSE)
  writeLines("b", file.path(empty, "b.txt"))
  dir.create(file.path(root, "plain"))

  dormant <- mk_repo("dormant", "git@github.com:acme/dormant.git",
                     commit = FALSE)
  old_date <- format(Sys.time() - 30 * 86400, "%Y-%m-%dT%H:%M:%S")
  writeLines("a", file.path(dormant, "a.txt"))
  git_in(dormant, "add", "a.txt")
  git_in(dormant, "commit", "-q", "-m", shQuote("Old commit"),
         "--date", shQuote(old_date),
         env = paste0("GIT_COMMITTER_DATE=", old_date))
  writeLines("b", file.path(dormant, "b.txt"))

  busy <- mk_repo("busy", "git@github.com:acme/busy.git")
  for (n in 2:4) {
    writeLines(as.character(n), file.path(busy, "a.txt"))
    git_in(busy, "commit", "-q", "-a", "-m", shQuote(paste("Commit", n)))
  }

  s2 <- hacer::survey(cfg = cfg, root = root, owners = "acme",
                      tasks_dir = NULL, github = FALSE)
  g2 <- s2[s2$source == "git", ]
  expect_equal(sort(unique(g2$project)), c("active", "busy", "dormant"),
               info = "owner filter keeps acme repos; no-history repo skipped")
  expect_true(grepl("4 commits in 3 days, latest: Commit 4 | Commit 3 | Commit 2",
                    g2$detail[g2$project == "busy" & g2$signal == "commits"],
                    fixed = TRUE),
              info = "up to three recent subjects, newest first")
  rep2 <- hacer::survey_report(s2)
  expect_true(any(rep2 == "## busy (in flight)"),
              info = "repo spelling names the section")

  a2 <- g2[g2$project == "active", ]
  expect_equal(a2$priority[a2$signal == "dirty"], 1L,
               info = "dirty worktree on an active repo is P1")
  expect_equal(a2$priority[a2$signal == "commits"], 2L,
               info = "commits in the window are P2")
  expect_true(grepl("1 commit in 3 days, latest: First commit",
                    a2$detail[a2$signal == "commits"], fixed = TRUE))
  expect_true(any(a2$signal == "unpushed" & grepl("no upstream", a2$detail)),
              info = "checked-out branch without upstream is reported")
  expect_equal(unique(a2$path), active)
  expect_inherits(a2$updated, "POSIXct")

  d2 <- g2[g2$project == "dormant", ]
  expect_equal(d2$signal[d2$priority == 3L], "dirty",
               info = "dirty worktree on a dormant repo is P3")
  expect_false(any(d2$signal == "commits"),
               info = "old commit is outside the window")

  s3 <- hacer::survey(cfg = cfg, root = root, owners = NULL,
                      tasks_dir = NULL, github = FALSE)
  expect_equal(sort(unique(s3$project[s3$source == "git"])),
               c("active", "busy", "dormant", "theirs"),
               info = "owners = NULL keeps every repo with history")

  s4 <- hacer::survey(cfg = cfg, repos = theirs, owners = NULL,
                      tasks_dir = NULL, github = FALSE)
  expect_equal(unique(s4$project[s4$source == "git"]), "theirs",
               info = "explicit repos bypass root")

  expect_equal(hacer:::.remote_owner("git@github.com:acme/x.git"), "acme")
  expect_equal(hacer:::.remote_owner("https://github.com/acme/x"), "acme")
  expect_true(is.na(hacer:::.remote_owner("x")))
}

unlink(root, recursive = TRUE)
