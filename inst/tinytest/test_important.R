# test_important.R - [!] marks an important item; #blocked tags a blocked one

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "archive"), recursive = TRUE, showWarnings = FALSE)
  d
}

# Extract the status character from inside [...] of a line.
status_in <- function(line) {
  m <- regmatches(line, regexec("\\[(.)\\]", line))[[1]]
  if (length(m) >= 2L) m[2] else NA_character_
}

# Write a daily file, run fix_parents(), return the resulting lines.
write_and_fix <- function(lines) {
  f <- tempfile(fileext = ".md")
  writeLines(c("# todo_250915_daily.md", "", lines), f)
  hacer::fix_parents(file_name = f)
  out <- readLines(f, warn = FALSE)
  unlink(f)
  out
}

# ---- Case 1: parse_todo() accepts [!] and reports status = "!" ----
tmp1 <- tempfile(fileext = ".md")
writeLines(c(
  "# todo_250915_daily.md",
  "",
  "- [!] Important one",
  "- [ ] Plain todo"
), tmp1)
df1 <- hacer::parse_todo(tmp1, period = "Daily", indent = 2L)
expect_equal(df1$status, c("!", " "),
             info = "parse_todo emits '!' for [!] tasks")
unlink(tmp1)

# ---- Case 2: an important child does not bubble up to its parent ----
out2 <- write_and_fix(c(
  "- [ ] House",
  "  - [!] Important child",
  "  - [ ] Plain child"
))
expect_equal(status_in(grep("\\bHouse$", out2, value = TRUE)[1]), " ",
             info = "Parent stays open when a child is [!]")

# ---- Case 3: [!] counts as open among done siblings ----
out3 <- write_and_fix(c(
  "- [ ] Project",
  "  - [x] Done sibling",
  "  - [!] Important sibling"
))
expect_equal(status_in(grep("\\bProject$", out3, value = TRUE)[1]), "/",
             info = "Done + important rolls the parent to [/]")

# ---- Case 4: an important parent keeps its marker while children are open ----
out4 <- write_and_fix(c(
  "- [!] Launch",
  "  - [/] Step one",
  "  - [ ] Step two"
))
expect_equal(status_in(grep("\\bLaunch$", out4, value = TRUE)[1]), "!",
             info = "Important parent keeps [!] with children in progress")

# ---- Case 5: an important parent closes when all children are done ----
out5 <- write_and_fix(c(
  "- [!] Launch",
  "  - [x] Step one",
  "  - [x] Step two"
))
expect_equal(status_in(grep("\\bLaunch$", out5, value = TRUE)[1]), "x",
             info = "All children done closes an important parent")

# ---- Case 6: a deep [!] leaves every ancestor alone ----
out6 <- write_and_fix(c(
  "- [ ] Grandparent",
  "  - [ ] Parent",
  "    - [!] Important grandchild"
))
expect_equal(status_in(grep("Grandparent", out6, value = TRUE)[1]), " ",
             info = "Grandparent unaffected by a deep [!]")
expect_equal(status_in(grep("\\bParent$", out6, value = TRUE)[1]), " ",
             info = "Parent unaffected by a direct [!] child")

# ---- Case 7: tasks() normalizes [!] to "important" and flags #blocked ----
repo7 <- tmp_repo()
cfg7 <- list(live_dir = file.path(repo7, "this_week"), indent = 2L)
writeLines(c(
  "# todo_250915_daily.md",
  "",
  "- [!] Important",
  "- [ ] Waiting on vendor #blocked",
  "- [/] Rolling #Blocked, see notes",
  "- [ ] Not #blockedtag"
), file.path(cfg7$live_dir, "todo_250915_daily.md"))
df7 <- hacer::tasks(cfg = cfg7)
expect_equal(df7$status, c("important", "todo", "in_progress", "todo"),
             info = "tasks() normalizes [!] to status='important'")
expect_equal(df7$blocked, c(FALSE, TRUE, TRUE, FALSE),
             info = "#blocked tag sets the blocked column, case-insensitively")
expect_equal(df7$text[2], "Waiting on vendor #blocked",
             info = "The tag stays in the text")
expect_equal(nrow(hacer::tasks(cfg = cfg7, blocked = TRUE)), 2L,
             info = "blocked=TRUE selects tagged rows")
expect_equal(hacer::tasks(cfg = cfg7, status = "important")$text, "Important",
             info = "status='important' selects [!] rows")
unlink(repo7, recursive = TRUE)

# ---- Case 8: run_monday() preserves [!] across the week boundary ----
repo8 <- tmp_repo()
cfg8 <- list(
  tz = "America/Chicago",
  indent = 2L,
  live_dir = file.path(repo8, "this_week"),
  archive_dir = file.path(repo8, "archive"),
  filename_fmt = "todo_%y%m%d_%s.md",
  daily_sections = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"),
  render_html = FALSE
)

prev_mon <- as.Date("2025-09-08")
this_mon <- as.Date("2025-09-15")

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg8$live_dir,
                 sprintf("todo_%s_%s.md",
                         format(prev_mon, "%y%m%d"), tolower(p)))
  writeLines(c(
    paste0("# todo_", format(prev_mon, "%y%m%d"), "_", tolower(p), ".md"),
    "",
    "- [!] Important persists",
    "- [ ] Plain todo",
    "- [x] Done dropped"
  ), f)
}

hacer::run_monday(date = this_mon, cfg = cfg8)

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg8$live_dir,
                 sprintf("todo_%s_%s.md",
                         format(this_mon, "%y%m%d"), tolower(p)))
  expect_true(file.exists(f),
              info = paste("run_monday creates new", p, "file"))
  out <- readLines(f, warn = FALSE)
  expect_true(any(grepl("\\[!\\].*Important persists", out)),
              info = paste("[!] preserved verbatim in new", p))
}

unlink(repo8, recursive = TRUE)
