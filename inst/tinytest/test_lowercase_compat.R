# test_lowercase_compat.R - readers accept legacy capitalized filenames
# (pre-0.1.7 repos use ToDo_*.txt; new writes always emit todo_*.txt)

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "archive"), recursive = TRUE, showWarnings = FALSE)
  d
}

# ---- tasks() lists capitalized files ----
repo1 <- tmp_repo()
cfg1 <- list(live_dir = file.path(repo1, "this_week"), indent = 2L)
writeLines(c("# legacy", "", "[ ] - Legacy task"),
           file.path(cfg1$live_dir, "ToDo_250915_Daily.txt"))
df1 <- hacer::tasks(cfg = cfg1)
expect_equal(nrow(df1), 1L,
             info = "tasks() finds capitalized legacy files")
expect_equal(df1$file, "ToDo_250915_Daily.txt",
             info = "tasks() preserves source case in the file column")
unlink(repo1, recursive = TRUE)

# ---- roll_day reads capitalized, writes lowercase ----
repo2 <- tmp_repo()
cfg2 <- list(live_dir = file.path(repo2, "this_week"), indent = 2L)
src <- file.path(cfg2$live_dir, "ToDo_250915_Daily.txt")
writeLines(c("# legacy", "", "[ ] - Carry forward", "[x] - Done"), src)

hacer::roll_day(date = as.Date("2025-09-16"), cfg = cfg2)

dst_md <- file.path(cfg2$live_dir, "todo_250916_daily.md")
dst_txt_lo <- file.path(cfg2$live_dir, "todo_250916_daily.txt")
dst_txt_up <- file.path(cfg2$live_dir, "ToDo_250916_Daily.txt")
expect_true(file.exists(dst_md),
            info = "roll_day writes the new file as .md")
expect_false(file.exists(dst_txt_lo),
             info = "roll_day does not write lowercase .txt")
expect_false(file.exists(dst_txt_up),
             info = "roll_day does not write capitalized .txt")
expect_true(file.exists(src),
            info = "Source capitalized file is left in place")
unlink(repo2, recursive = TRUE)

# ---- run_monday reads legacy capitalized prev week, writes .md next week ----
repo3 <- tmp_repo()
cfg3 <- list(
  tz = "America/Chicago",
  indent = 2L,
  live_dir    = file.path(repo3, "this_week"),
  archive_dir = file.path(repo3, "archive"),
  filename_fmt = "todo_%y%m%d_%s.md",
  daily_sections = c("Monday","Tuesday","Wednesday","Thursday","Friday"),
  render_html = FALSE
)
prev_mon <- as.Date("2025-09-08")
this_mon <- as.Date("2025-09-15")
for (p in c("Daily","Week","Month","Quarter")) {
  f <- file.path(cfg3$live_dir,
                 sprintf("ToDo_%s_%s.txt", format(prev_mon, "%y%m%d"), p))
  writeLines(c(
    paste0("# legacy_", p),
    "",
    "[ ] - One per file"
  ), f)
}

hacer::run_monday(date = this_mon, cfg = cfg3)

for (p in c("Daily","Week","Month","Quarter")) {
  new_f <- file.path(cfg3$live_dir,
                     sprintf("todo_%s_%s.md",
                             format(this_mon, "%y%m%d"), tolower(p)))
  expect_true(file.exists(new_f),
              info = paste("run_monday writes new .md", p, "filename"))
}
unlink(repo3, recursive = TRUE)
