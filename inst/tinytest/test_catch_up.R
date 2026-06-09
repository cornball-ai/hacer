# test_catch_up.R - catch_up rolls missing weeks

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

for (kind in c("daily", "week", "month", "quarter")) {
  f <- file.path(cfg$live_dir, paste0("todo_250908_", kind, ".md"))
  if (kind == "daily") {
    writeLines(c("# todo_250908_daily.md", "", "## Monday", "", "- [ ] One", "", "## Tuesday", "", "## Wednesday", "", "## Thursday", "", "## Friday"), f)
  } else {
    writeLines(c(paste0("# todo_250908_", kind, ".md"), "", "- [ ] One"), f)
  }
}

rolled_preview <- hacer::catch_up(date = as.Date("2025-09-22"), cfg = cfg,
                                  preview = TRUE)
expect_equal(format(rolled_preview), c("2025-09-15", "2025-09-22"))
expect_false(file.exists(file.path(cfg$live_dir, "todo_250922_daily.md")),
             info = "preview does not write")

rolled <- hacer::catch_up(date = as.Date("2025-09-22"), cfg = cfg,
                          preview = FALSE)
expect_equal(format(rolled), c("2025-09-15", "2025-09-22"))
expect_true(file.exists(file.path(cfg$live_dir, "todo_250922_daily.md")))
expect_true(file.exists(file.path(cfg$live_dir, "todo_250922_week.md")))

unlink(repo, recursive = TRUE)
