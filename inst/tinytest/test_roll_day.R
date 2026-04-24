# test_roll_day.R - Tests for roll_day() function

library(hacer)

# Helper to make a temp repo
tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  d
}

# ---- Case 1: One-list mode rolls Daily only ----
repo1 <- tmp_repo()
cfg1 <- list(
  live_dir = file.path(repo1, "this_week"),
  indent = 2L
)

f1 <- file.path(cfg1$live_dir, "ToDo_250915_Daily.txt")
writeLines(c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "# Monday",
  "",
  "[ ] - House",
  "  [/] - Drywall Test",
  "  [x] - Paint Trim",
  "",
  "[ ] -*Exercise",
  "[x] - One-time task"
), f1)

roll_day(date = as.Date("2025-09-16"), cfg = cfg1)

f1_today <- file.path(cfg1$live_dir, "ToDo_250916_Daily.txt")
expect_true(file.exists(f1_today),
            info = "One-list mode: today's Daily file should be created")

out1 <- readLines(f1_today, warn = FALSE)
expect_true(any(grepl("House", out1)), info = "Pending parent should carry forward")
expect_true(any(grepl("Drywall Test", out1)), info = "In-progress child should carry forward")
expect_false(any(grepl("One-time task", out1)), info = "Non-recurring done task should be dropped")
expect_true(any(grepl("\\[ \\] -\\*Exercise", out1)), info = "Recurring task should carry forward")

# done.log should contain dropped item
done1 <- readLines(file.path(repo1, "done.log"), warn = FALSE)
expect_true(any(grepl("One-time task", done1)), info = "Dropped item should appear in done.log")

unlink(repo1, recursive = TRUE)

# ---- Case 2: Four-cadence mode rolls all four ----
repo2 <- tmp_repo()
cfg2 <- list(
  live_dir = file.path(repo2, "this_week"),
  indent = 2L
)

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg2$live_dir, sprintf("ToDo_250915_%s.txt", p))
  writeLines(c(
    paste0("# ToDo_250915_", p, ".txt"),
    "",
    "#######################################",
    "",
    "[ ] - Task",
    "[x] - Done task"
  ), f)
}

roll_day(date = as.Date("2025-09-16"), cfg = cfg2)

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg2$live_dir, sprintf("ToDo_250916_%s.txt", p))
  expect_true(file.exists(f),
              info = paste("Four-cadence mode: today's", p, "file should be created"))
  out <- readLines(f, warn = FALSE)
  expect_false(any(grepl("Done task", out)),
               info = paste("Dropped done task should not appear in", p))
}

done2 <- readLines(file.path(repo2, "done.log"), warn = FALSE)
expect_equal(length(done2), 4L,
             info = "Four dropped items should be logged")

unlink(repo2, recursive = TRUE)

# ---- Case 3: Recurring [x] resets to [ ] ----
repo3 <- tmp_repo()
cfg3 <- list(
  live_dir = file.path(repo3, "this_week"),
  indent = 2L
)

f3 <- file.path(cfg3$live_dir, "ToDo_250915_Daily.txt")
writeLines(c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "[x] -*Exercise",
  "[x] - One-time"
), f3)

roll_day(date = as.Date("2025-09-16"), cfg = cfg3)

out3 <- readLines(file.path(cfg3$live_dir, "ToDo_250916_Daily.txt"), warn = FALSE)
expect_true(any(grepl("\\[ \\] -\\*Exercise", out3)),
            info = "Recurring done task should reset to blank")
expect_false(any(grepl("One-time", out3)),
             info = "Non-recurring done task should be dropped")

unlink(repo3, recursive = TRUE)

# ---- Case 4: [/] and [!] carry forward unchanged ----
repo4 <- tmp_repo()
cfg4 <- list(
  live_dir = file.path(repo4, "this_week"),
  indent = 2L
)

f4 <- file.path(cfg4$live_dir, "ToDo_250915_Daily.txt")
writeLines(c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "[/] - In progress",
  "[!] - Blocked"
), f4)

roll_day(date = as.Date("2025-09-16"), cfg = cfg4)

out4 <- readLines(file.path(cfg4$live_dir, "ToDo_250916_Daily.txt"), warn = FALSE)
expect_true(any(grepl("\\[/\\] - In progress", out4)),
            info = "In-progress task should carry forward unchanged")
expect_true(any(grepl("\\[!\\] - Blocked", out4)),
            info = "Blocked task should carry forward unchanged")

unlink(repo4, recursive = TRUE)

# ---- Case 5: Parent/child indentation preserved ----
repo5 <- tmp_repo()
cfg5 <- list(
  live_dir = file.path(repo5, "this_week"),
  indent = 2L
)

f5 <- file.path(cfg5$live_dir, "ToDo_250915_Daily.txt")
writeLines(c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "[ ] - Parent",
  "  [x] - Child done",
  "  [ ] - Child pending"
), f5)

roll_day(date = as.Date("2025-09-16"), cfg = cfg5)

out5 <- readLines(file.path(cfg5$live_dir, "ToDo_250916_Daily.txt"), warn = FALSE)
child_pending_line <- grep("Child pending", out5, value = TRUE)
expect_true(grepl("^  ", child_pending_line),
            info = "Child indentation should be preserved")

unlink(repo5, recursive = TRUE)

# ---- Case 6: Empty input is a no-op with a message ----
repo6 <- tmp_repo()
cfg6 <- list(
  live_dir = file.path(repo6, "this_week"),
  indent = 2L
)

# capture message
msg <- capture.output(roll_day(date = as.Date("2025-09-16"), cfg = cfg6), type = "message")
expect_true(any(grepl("No prior files found", msg)),
            info = "Empty input should produce a clear message")

unlink(repo6, recursive = TRUE)

# ---- Case 7: done.log is appended if present ----
repo7 <- tmp_repo()
cfg7 <- list(
  live_dir = file.path(repo7, "this_week"),
  indent = 2L
)

writeLines("2025-09-14  Old entry", file.path(repo7, "done.log"))

f7 <- file.path(cfg7$live_dir, "ToDo_250915_Daily.txt")
writeLines(c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "[x] - New done"
), f7)

roll_day(date = as.Date("2025-09-16"), cfg = cfg7)

done7 <- readLines(file.path(repo7, "done.log"), warn = FALSE)
expect_true(any(grepl("Old entry", done7)), info = "Old done.log entry should persist")
expect_true(any(grepl("New done", done7)), info = "New entry should be appended")

unlink(repo7, recursive = TRUE)
