# test_recurring.R - Tests for recurring-task manifest

library(hacer)

# ---- Frequency parser ----
expect_equal(hacer:::.parse_freq("M")$days, 1L,
             info = "M -> Monday only")
expect_equal(hacer:::.parse_freq("R")$days, 4L,
             info = "R -> Thursday only")
expect_equal(hacer:::.parse_freq("MR")$days, c(1L, 4L),
             info = "MR -> Mon + Thu")
expect_equal(hacer:::.parse_freq("MTWRF")$days, 1:5,
             info = "MTWRF -> all weekdays")
expect_equal(hacer:::.parse_freq("*")$days, 1:5,
             info = "* alias for MTWRF")
expect_equal(hacer:::.parse_freq("1W:M")$week_of_month, 1L,
             info = "1W:M parses week_of_month")
expect_equal(hacer:::.parse_freq("1W:M")$days, 1L,
             info = "1W:M parses Monday")
expect_equal(hacer:::.parse_freq("3W:MR")$week_of_month, 3L,
             info = "3W:MR parses week 3")
expect_equal(hacer:::.parse_freq("3W:MR")$days, c(1L, 4L),
             info = "3W:MR parses Mon + Thu")
expect_error(hacer:::.parse_freq("Q"), pattern = "Bad day code",
             info = "Unknown day code errors")

# ---- read_recurring ----
tmp <- tempfile()
writeLines(c(
  "# A comment",
  "",
  "M       Email",
  "MR      wiki         # inline comment",
  "*       Exercise",
  "1W:M    Bills",
  "MTWR    cornball.ai > Lil Casey > Countdown"
), tmp)
rec <- read_recurring(tmp)
expect_equal(nrow(rec), 5L,
             info = "5 manifest entries (comments and blanks ignored)")
expect_equal(rec$path,
             c("Email", "wiki", "Exercise", "Bills",
               "cornball.ai > Lil Casey > Countdown"),
             info = "Paths parse with > separator")
expect_equal(rec$name,
             c("Email", "wiki", "Exercise", "Bills", "Countdown"),
             info = "name is leaf component")
expect_equal(rec$level, c(0L, 0L, 0L, 0L, 2L),
             info = "level reflects path depth")
expect_equal(rec$parent_path[5], "cornball.ai > Lil Casey",
             info = "parent_path drops the leaf")
expect_true(is.na(rec$parent_path[1]),
            info = "Top-level entries have NA parent_path")
unlink(tmp)

# Empty/missing manifest
empty_rec <- read_recurring(tempfile())
expect_equal(nrow(empty_rec), 0L,
             info = "Missing manifest file yields empty df, not error")

# ---- .recurring_for_date ----
rec2 <- read_recurring(tmp_rec <- {
  f <- tempfile()
  writeLines(c(
    "M       MondayOnly",
    "MR      MonAndThu",
    "*       Daily",
    "1W:M    FirstMonday"
  ), f)
  f
})

# 2025-09-15 is Monday, week 3 of September (15 falls in 15-21 → week 3)
mon_w3 <- as.Date("2025-09-15")
hits <- hacer:::.recurring_for_date(rec2, mon_w3)
expect_true("MondayOnly" %in% hits$path,
            info = "MondayOnly matches a Monday")
expect_true("MonAndThu" %in% hits$path,
            info = "MonAndThu matches a Monday")
expect_true("Daily" %in% hits$path,
            info = "Daily matches a Monday")
expect_false("FirstMonday" %in% hits$path,
             info = "1W:M does not match week-3 Monday")

# 2025-09-01 is a Monday in week 1 of September
mon_w1 <- as.Date("2025-09-01")
hits <- hacer:::.recurring_for_date(rec2, mon_w1)
expect_true("FirstMonday" %in% hits$path,
            info = "1W:M matches first-week Monday")

# Tuesday 2025-09-16: only Daily applies (MondayOnly and MonAndThu don't)
tue <- as.Date("2025-09-16")
hits <- hacer:::.recurring_for_date(rec2, tue)
expect_true("Daily" %in% hits$path)
expect_false("MondayOnly" %in% hits$path)
expect_false("MonAndThu" %in% hits$path)

# Thursday 2025-09-18: MonAndThu and Daily apply
thu <- as.Date("2025-09-18")
hits <- hacer:::.recurring_for_date(rec2, thu)
expect_true("MonAndThu" %in% hits$path,
            info = "MonAndThu matches Thursday")
expect_true("Daily" %in% hits$path)
expect_false("MondayOnly" %in% hits$path)

unlink(tmp_rec)

# ---- run_monday integrates the manifest ----
repo <- tempfile()
dir.create(file.path(repo, "this_week"), recursive = TRUE)
dir.create(file.path(repo, "archive"),   recursive = TRUE)

writeLines(c(
  "M       Email",
  "M       todo",
  "MR      wiki",
  "*       Exercise",
  "MTWR    cornball.ai > Lil Casey > Countdown"
), file.path(repo, "recurring.txt"))

# Sparse prev-week files. Carry-forward takes any non-recurring user tasks.
for (p in c("daily", "week", "month", "quarter")) {
  writeLines(c(
    paste0("# todo_250915_", p),
    "",
    "[/] - One-off in progress"
  ), file.path(repo, "this_week", sprintf("todo_250915_%s.txt", p)))
}

cfg <- list(
  tz = "UTC", indent = 2L,
  live_dir = file.path(repo, "this_week"),
  archive_dir = file.path(repo, "archive"),
  daily_sections = c("Monday","Tuesday","Wednesday","Thursday","Friday"),
  render_markdown = FALSE, render_html = FALSE
)
hacer::run_monday(date = as.Date("2025-09-22"), cfg = cfg)

new_daily <- readLines(file.path(repo, "this_week", "todo_250922_daily.txt"),
                       warn = FALSE)
combined <- paste(new_daily, collapse = "\n")

# Monday section has Email, todo, wiki, Exercise, cornball.ai > Lil Casey > Countdown
mon_idx <- grep("^# Monday\\s*$", new_daily)
fri_idx <- grep("^# Friday\\s*$", new_daily)
mon_section <- paste(new_daily[mon_idx:(fri_idx - 1L)], collapse = "\n")
expect_true(grepl("\\[ \\] -\\*Email", mon_section),
            info = "Monday materializes Email")
expect_true(grepl("\\[ \\] -\\*todo", mon_section),
            info = "Monday materializes todo")
expect_true(grepl("\\[ \\] -\\*wiki", mon_section),
            info = "Monday materializes wiki")
expect_true(grepl("Countdown", mon_section),
            info = "Monday materializes nested Countdown")

# Tuesday section: NOT Email/todo (M-only), NOT wiki (MR-only). Exercise + Countdown only.
tue_idx <- grep("^# Tuesday\\s*$", new_daily)
wed_idx <- grep("^# Wednesday\\s*$", new_daily)
tue_section <- paste(new_daily[tue_idx:(wed_idx - 1L)], collapse = "\n")
expect_false(grepl("Email", tue_section),
             info = "Tuesday omits Email (M-only)")
expect_false(grepl("wiki", tue_section),
             info = "Tuesday omits wiki (MR-only)")
expect_true(grepl("Exercise", tue_section),
            info = "Tuesday includes Exercise (*)")
expect_true(grepl("Countdown", tue_section),
            info = "Tuesday includes Countdown (MTWR)")

# Friday section: ONLY Exercise (Countdown is MTWR no F).
fri_section <- paste(new_daily[fri_idx:length(new_daily)], collapse = "\n")
expect_true(grepl("Exercise", fri_section),
            info = "Friday has Exercise")
expect_false(grepl("Countdown", fri_section),
             info = "Friday omits Countdown (MTWR no F)")

# Carry-forward non-recurring task survives
expect_true(grepl("One-off in progress", combined),
            info = "Non-recurring carry-forward preserved")

unlink(repo, recursive = TRUE)

# ---- instantiate_todo writes recurring.txt ----
repo2 <- tempfile()
hacer::instantiate_todo(repo2)
expect_true(file.exists(file.path(repo2, "recurring.txt")),
            info = "instantiate_todo creates recurring.txt")
rec_seed <- readLines(file.path(repo2, "recurring.txt"), warn = FALSE)
expect_true(any(grepl("M\\s+Email", rec_seed)),
            info = "Starter manifest has Email entry")
expect_true(any(grepl("\\*\\s+Exercise", rec_seed)),
            info = "Starter manifest has Exercise entry")
unlink(repo2, recursive = TRUE)
