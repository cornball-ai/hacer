# test_snapshot.R - snapshot() and archive_old() for the single-file workflow

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "archive"), recursive = TRUE, showWarnings = FALSE)
  d
}

cfg_for <- function(repo) {
  list(live_dir = file.path(repo, "this_week"),
       archive_dir = file.path(repo, "archive"),
       indent = 2L)
}

todo_lines <- c("- [ ] Project", "  - [/] Step", "- [!] Flagged")

# ---- Case 1: snapshot copies todo.md to a dated file ----
r1 <- tmp_repo()
cfg1 <- cfg_for(r1)
writeLines(todo_lines, hacer::todo_file(cfg1))
expect_equal(hacer::todo_file(cfg1), file.path(cfg1$live_dir, "todo.md"))

out1 <- hacer::snapshot(date = as.Date("2026-10-28"), cfg = cfg1,
                        archive = FALSE)
expect_equal(out1, file.path(cfg1$live_dir, "todo_261028.md"),
             info = "snapshot returns the dated path")
expect_identical(readLines(out1), todo_lines,
                 info = "snapshot is a verbatim copy")

# An existing snapshot is left alone unless overwrite = TRUE
writeLines(c(todo_lines, "- [ ] Added later"), hacer::todo_file(cfg1))
expect_message(
  hacer::snapshot(date = as.Date("2026-10-28"), cfg = cfg1, archive = FALSE),
  "not overwriting")
expect_identical(readLines(out1), todo_lines,
                 info = "existing snapshot untouched")
hacer::snapshot(date = as.Date("2026-10-28"), cfg = cfg1, archive = FALSE,
                overwrite = TRUE)
expect_equal(length(readLines(out1)), 4L,
             info = "overwrite = TRUE replaces the snapshot")

# Default date is yesterday (the 2am run captures the day that just ended)
hacer::snapshot(cfg = cfg1, archive = FALSE)
yday <- file.path(cfg1$live_dir,
                  sprintf("todo_%s.md", format(Sys.Date() - 1L, "%y%m%d")))
expect_true(file.exists(yday), info = "default snapshot is dated yesterday")

r1b <- tmp_repo()
expect_error(hacer::snapshot(cfg = cfg_for(r1b)), "not found",
             info = "missing todo.md errors clearly")
unlink(c(r1, r1b), recursive = TRUE)

# ---- Case 2: preview reports the copy and the moves, writes nothing ----
r2 <- tmp_repo()
cfg2 <- cfg_for(r2)
writeLines(todo_lines, hacer::todo_file(cfg2))
writeLines("old", file.path(cfg2$live_dir, "todo_261019.md"))
pv2 <- hacer::snapshot(date = as.Date("2026-10-28"), cfg = cfg2,
                       before = as.Date("2026-10-26"), preview = TRUE)
expect_inherits(pv2, "hacer_preview")
expect_equal(pv2$files_created, file.path(cfg2$live_dir, "todo_261028.md"),
             info = "preview lists the snapshot as created")
expect_equal(pv2$files_moved$from, file.path(cfg2$live_dir, "todo_261019.md"),
             info = "preview lists the sweep source")
expect_equal(pv2$files_moved$to, file.path(cfg2$archive_dir, "todo_261019.md"),
             info = "preview lists the sweep target")
expect_false(file.exists(file.path(cfg2$live_dir, "todo_261028.md")),
             info = "preview writes no snapshot")
expect_true(file.exists(file.path(cfg2$live_dir, "todo_261019.md")),
            info = "preview moves nothing")
expect_true(any(grepl("moved (1)", capture.output(print(pv2)), fixed = TRUE)),
            info = "print shows the moves")
unlink(r2, recursive = TRUE)

# ---- Case 3: archive_old moves dated files from before the cutoff ----
r3 <- tmp_repo()
cfg3 <- cfg_for(r3)
live3 <- cfg3$live_dir
writeLines(todo_lines, hacer::todo_file(cfg3))
old_names <- c("todo_261019.md", "todo_261013_daily.md",
               "ToDo_261013_Daily.txt", "todo_261020_week.html")
keep_names <- c("todo_261026.md", "todo_261027.md", "recurring.txt",
                "notes_261001.md")
for (nm in c(old_names, keep_names)) writeLines(nm, file.path(live3, nm))

moves3 <- hacer::archive_old(cfg = cfg3, before = as.Date("2026-10-26"))
expect_equal(sort(basename(moves3$from)), sort(old_names),
             info = "every dated file before the cutoff is moved")
expect_true(all(file.exists(file.path(cfg3$archive_dir, old_names))),
            info = "moved files land in the archive")
expect_false(any(file.exists(file.path(live3, old_names))),
             info = "moved files leave live_dir")
expect_true(all(file.exists(file.path(live3, c(keep_names, "todo.md")))),
            info = "this week's files, todo.md and undated files stay")
expect_equal(nrow(hacer::archive_old(cfg = cfg3, before = as.Date("2026-10-26"))),
             0L, info = "second sweep finds nothing")
unlink(r3, recursive = TRUE)

# ---- Case 4: name clashes: identical copy deduped, different copy left ----
r4 <- tmp_repo()
cfg4 <- cfg_for(r4)
writeLines("same", file.path(cfg4$live_dir, "todo_261019.md"))
writeLines("same", file.path(cfg4$archive_dir, "todo_261019.md"))
writeLines("live", file.path(cfg4$live_dir, "todo_261020.md"))
writeLines("archived", file.path(cfg4$archive_dir, "todo_261020.md"))
expect_warning(
  moves4 <- hacer::archive_old(cfg = cfg4, before = as.Date("2026-10-26")),
  "different")
expect_equal(basename(moves4$from), "todo_261019.md",
             info = "only the deduped file counts as moved")
expect_false(file.exists(file.path(cfg4$live_dir, "todo_261019.md")),
             info = "identical live copy removed")
expect_true(file.exists(file.path(cfg4$live_dir, "todo_261020.md")),
            info = "conflicting live copy kept")
expect_equal(readLines(file.path(cfg4$archive_dir, "todo_261020.md")),
             "archived", info = "archive copy never overwritten")
unlink(r4, recursive = TRUE)

# ---- Case 5: commit = TRUE commits only the moved files ----
if (nzchar(Sys.which("git"))) {
  r5 <- tmp_repo()
  cfg5 <- cfg_for(r5)
  git5 <- function(...) {
    suppressWarnings(system2("git", c("-C", shQuote(r5), ...),
                             stdout = TRUE, stderr = TRUE))
  }
  git5("init", "-q")
  git5("config", "user.email", "test@example.com")
  git5("config", "user.name", "hacer tests")
  writeLines("unrelated", file.path(r5, "unrelated.txt"))
  writeLines(todo_lines, hacer::todo_file(cfg5))
  writeLines("old", file.path(cfg5$live_dir, "todo_261019.md"))

  hacer::snapshot(date = as.Date("2026-10-28"), cfg = cfg5,
                  before = as.Date("2026-10-26"), commit = TRUE)
  expect_equal(git5("log", "--format=%s"),
               "Archive todo files before 2026-10-26",
               info = "one commit with the archive message")
  expect_equal(git5("ls-files"), "archive/todo_261019.md",
               info = "only the moved file is tracked")
  expect_true(file.exists(file.path(cfg5$live_dir, "todo_261028.md")),
              info = "snapshot still written")

  hacer::snapshot(date = as.Date("2026-10-27"), cfg = cfg5,
                  before = as.Date("2026-10-26"), commit = TRUE)
  expect_equal(length(git5("log", "--format=%s")), 1L,
               info = "nothing to move means no new commit")
  unlink(r5, recursive = TRUE)

  r5b <- tmp_repo()
  cfg5b <- cfg_for(r5b)
  writeLines("old", file.path(cfg5b$live_dir, "todo_261019.md"))
  expect_warning(
    hacer::archive_old(cfg = cfg5b, before = as.Date("2026-10-26"),
                       commit = TRUE),
    "not in a git repository")
  expect_true(file.exists(file.path(cfg5b$archive_dir, "todo_261019.md")),
              info = "move still happens outside a repo")
  unlink(r5b, recursive = TRUE)
}
