# test_blocked.R - Tests for [!] blocked status (parse + rollup + rollover)

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "archive"), recursive = TRUE, showWarnings = FALSE)
  d
}

# ---- Case 1: parse_todo() accepts [!] and reports status = "!" ----
tmp1 <- tempfile(fileext = ".txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[!] - Blocked one",
  "[ ] - Plain todo"
), tmp1)

df1 <- hacer:::parse_todo(tmp1, period = "Daily", indent = 2L)
expect_equal(df1$status, c("!", " "),
             info = "parse_todo emits '!' for [!] tasks")
unlink(tmp1)

# ---- Case 2: fix_parents() rolls a parent to [!] when any child is blocked ----
tmp2 <- tempfile(fileext = ".txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "#######################################",
  "",
  "# Monday",
  "",
  "[ ] - House",
  "  [!] - Blocked child",
  "  [ ] - Plain child"
), tmp2)
hacer::fix_parents(file_name = tmp2)
out2 <- readLines(tmp2, warn = FALSE)
parent_line <- grep("- (\\*)?House$", out2, value = TRUE)
expect_equal(substr(sub("^\\s*", "", parent_line), 2, 2), "!",
             info = "Parent rolls to [!] when any direct child is blocked")
unlink(tmp2)

# ---- Case 3: fix_parents() bubbles [!] up across multiple levels ----
tmp3 <- tempfile(fileext = ".txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[ ] - Grandparent",
  "  [ ] - Parent",
  "    [!] - Blocked grandchild"
), tmp3)
hacer::fix_parents(file_name = tmp3)
out3 <- readLines(tmp3, warn = FALSE)
gp_line <- grep("Grandparent", out3, value = TRUE)
p_line  <- grep("- Parent", out3, value = TRUE)
expect_equal(substr(sub("^\\s*", "", gp_line), 2, 2), "!",
             info = "Grandparent rolls to [!] across two levels")
expect_equal(substr(sub("^\\s*", "", p_line), 2, 2), "!",
             info = "Direct parent rolls to [!]")
unlink(tmp3)

# ---- Case 4: [!] takes precedence over [x] siblings (would otherwise be done) ----
tmp4 <- tempfile(fileext = ".txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[ ] - Project",
  "  [x] - Done sibling",
  "  [x] - Another done",
  "  [!] - Blocked sibling"
), tmp4)
hacer::fix_parents(file_name = tmp4)
out4 <- readLines(tmp4, warn = FALSE)
parent_line4 <- grep("- (\\*)?Project$", out4, value = TRUE)
expect_equal(substr(sub("^\\s*", "", parent_line4), 2, 2), "!",
             info = "Blocked overrides 'all done' rollup")
unlink(tmp4)

# ---- Case 5: [!] takes precedence over [/] siblings ----
tmp5 <- tempfile(fileext = ".txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[ ] - Project",
  "  [/] - In progress",
  "  [!] - Blocked"
), tmp5)
hacer::fix_parents(file_name = tmp5)
out5 <- readLines(tmp5, warn = FALSE)
parent_line5 <- grep("- (\\*)?Project$", out5, value = TRUE)
expect_equal(substr(sub("^\\s*", "", parent_line5), 2, 2), "!",
             info = "Blocked overrides in-progress rollup")
unlink(tmp5)

# ---- Case 6: blocked + recurring sibling — parent is [!], recurring orthogonal ----
tmp6 <- tempfile(fileext = ".txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[ ] - Project",
  "  [ ] -*Recurring child",
  "  [!] - Blocked child"
), tmp6)
hacer::fix_parents(file_name = tmp6)
out6 <- readLines(tmp6, warn = FALSE)
parent_line6 <- grep("-\\s*\\*?Project$", out6, value = TRUE)
expect_equal(substr(sub("^\\s*", "", parent_line6), 2, 2), "!",
             info = "Recurring sibling does not affect blocked rollup")
unlink(tmp6)

# ---- Case 7: tasks() reports status = "blocked" for [!] (already covered, sanity check) ----
repo7 <- tmp_repo()
cfg7 <- list(live_dir = file.path(repo7, "this_week"), indent = 2L)
f7 <- file.path(cfg7$live_dir, "todo_250915_daily.txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[!] - Blocked"
), f7)
df7 <- hacer::tasks(cfg = cfg7)
expect_equal(df7$status, "blocked",
             info = "tasks() normalizes [!] to status='blocked'")
unlink(repo7, recursive = TRUE)

# ---- Case 8: run_monday() preserves [!] across the week boundary ----
# Build a previous-Monday file set, run roll_day-style advance via run_monday,
# and check that the new week still has [!] tasks.
repo8 <- tmp_repo()
cfg8 <- list(
  tz = "America/Chicago",
  indent = 2L,
  live_dir = file.path(repo8, "this_week"),
  archive_dir = file.path(repo8, "archive"),
  filename_fmt = "todo_%y%m%d_%s.txt",
  daily_sections = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"),
  render_markdown = FALSE,
  render_html = FALSE
)

prev_mon <- as.Date("2025-09-08")  # a Monday
this_mon <- as.Date("2025-09-15")

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg8$live_dir,
                 sprintf("todo_%s_%s.txt",
                         format(prev_mon, "%y%m%d"), tolower(p)))
  writeLines(c(
    paste0("# todo_", format(prev_mon, "%y%m%d"), "_", tolower(p), ".txt"),
    "",
    "#######################################",
    "",
    "[!] - Blocked persists",
    "[ ] - Plain todo",
    "[x] - Done dropped"
  ), f)
}

hacer::run_monday(date = this_mon, cfg = cfg8)

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg8$live_dir,
                 sprintf("todo_%s_%s.txt",
                         format(this_mon, "%y%m%d"), tolower(p)))
  expect_true(file.exists(f),
              info = paste("run_monday creates new", p, "file"))
  out <- readLines(f, warn = FALSE)
  expect_true(any(grepl("\\[!\\].*Blocked persists", out)),
              info = paste("[!] preserved verbatim in new", p))
}

unlink(repo8, recursive = TRUE)

# ---- Case 9: roll_day() preserves [!] (sanity duplicate of test_roll_day Case 4) ----
repo9 <- tmp_repo()
cfg9 <- list(live_dir = file.path(repo9, "this_week"), indent = 2L)
f9 <- file.path(cfg9$live_dir, "todo_250915_daily.txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[!] - Blocked",
  "  [!] - Blocked nested"
), f9)
hacer::roll_day(date = as.Date("2025-09-16"), cfg = cfg9)
out9 <- readLines(file.path(cfg9$live_dir, "todo_250916_daily.txt"),
                  warn = FALSE)
expect_true(any(grepl("\\[!\\] - Blocked$", out9)),
            info = "roll_day preserves top-level [!]")
expect_true(any(grepl("\\[!\\] - Blocked nested$", out9)),
            info = "roll_day preserves nested [!]")
unlink(repo9, recursive = TRUE)
