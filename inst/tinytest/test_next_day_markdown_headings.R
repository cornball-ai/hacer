# test_next_day_markdown_headings.R - next_day accepts markdown ## weekday headings

library(hacer)

repo <- tempfile()
dir.create(file.path(repo, "this_week"), recursive = TRUE, showWarnings = FALSE)
dir.create(file.path(repo, "archive"), recursive = TRUE, showWarnings = FALSE)

cfg <- list(
  tz = "America/Chicago",
  indent = 2L,
  live_dir = file.path(repo, "this_week"),
  archive_dir = file.path(repo, "archive"),
  filename_fmt = "todo_%y%m%d_%s.md",
  daily_sections = c("Monday", "Tuesday", "Wednesday", "Thursday", "Friday"),
  render_html = FALSE
)

f <- file.path(cfg$live_dir, "todo_250915_daily.md")
writeLines(c(
  "# todo_250915_daily.md",
  "",
  "## Monday",
  "",
  "## Tuesday",
  "",
  "- [ ] Carry this",
  "- [/] Keep progress",
  "- [x] Leave done",
  "",
  "## Wednesday",
  "",
  "- [ ] Existing Wednesday",
  "",
  "## Thursday",
  "",
  "## Friday"
), f)

hacer::next_day(date = as.Date("2025-09-16"), cfg = cfg, preview = FALSE)
lines <- readLines(f, warn = FALSE)

expect_true(any(lines == "## Tuesday"),
            info = "next_day preserves ## Tuesday heading")
expect_true(any(lines == "## Wednesday"),
            info = "next_day preserves ## Wednesday heading")
expect_true(any(lines == "- [ ] Carry this"),
            info = "unchecked task carries to tomorrow")
expect_true(any(lines == "- [/] Keep progress"),
            info = "in-progress task stays in today")
expect_false(any(grepl("Could not find sections", lines)),
             info = "markdown headings did not trip section lookup")

unlink(repo, recursive = TRUE)
