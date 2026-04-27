# test_migrate.R - Tests for migrate_to_markdown()

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  d
}

# ---- Case 1: Legacy .txt converts to .md with new syntax ----
repo1 <- tmp_repo()
cfg1 <- list(live_dir = file.path(repo1, "this_week"), indent = 2L)
src1 <- file.path(cfg1$live_dir, "todo_250915_daily.txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "# Monday",
  "",
  "[ ] - House",
  "  [/] - Drywall",
  "  [x] - Trim"
), src1)

invisible(capture.output(
  hacer::migrate_to_markdown(cfg = cfg1),
  type = "message"
))

dst1 <- file.path(cfg1$live_dir, "todo_250915_daily.md")
expect_true(file.exists(dst1),
            info = "migrate creates the .md file")
expect_false(file.exists(src1),
             info = "migrate removes the .txt source")

new_lines <- readLines(dst1, warn = FALSE)
combined <- paste(new_lines, collapse = "\n")
expect_true(grepl("- \\[ \\] House", combined),
            info = "House emitted as markdown task")
expect_true(grepl("- \\[/\\] Drywall", combined),
            info = "Drywall emitted as markdown task with [/] status")
expect_true(grepl("- \\[x\\] Trim", combined),
            info = "Trim emitted as markdown task with [x] status")
expect_true(grepl("## Monday", combined),
            info = "Day section header is H2")
expect_false(grepl("###############", combined),
             info = "Legacy ##### separator is dropped")
unlink(repo1, recursive = TRUE)

# ---- Case 2: Recurring `*` tasks surface in the warning message ----
repo2 <- tmp_repo()
cfg2 <- list(live_dir = file.path(repo2, "this_week"), indent = 2L)
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[ ] -*Email",
  "[ ] - One-off",
  "[ ] -*Exercise"
), file.path(cfg2$live_dir, "todo_250915_daily.txt"))

msgs <- capture.output(
  hacer::migrate_to_markdown(cfg = cfg2),
  type = "message"
)
combined_msg <- paste(msgs, collapse = "\n")
expect_true(grepl("legacy `\\*` recurring marker", combined_msg),
            info = "Warning header mentions legacy * marker")
expect_true(grepl("Email", combined_msg),
            info = "Warning lists Email as recurring")
expect_true(grepl("Exercise", combined_msg),
            info = "Warning lists Exercise as recurring")
expect_false(grepl("\\bOne-off\\b", combined_msg),
             info = "Non-recurring task is not in the warning")

# Verify the new file does NOT have `*` markers anywhere
new_lines2 <- readLines(file.path(cfg2$live_dir, "todo_250915_daily.md"),
                        warn = FALSE)
expect_false(any(grepl("\\*Email|\\*Exercise", new_lines2)),
             info = "Migrated file drops the * recurring marker")
unlink(repo2, recursive = TRUE)

# ---- Case 3: Empty live_dir is a no-op with a clear message ----
repo3 <- tmp_repo()
cfg3 <- list(live_dir = file.path(repo3, "this_week"), indent = 2L)
msg3 <- capture.output(
  hacer::migrate_to_markdown(cfg = cfg3),
  type = "message"
)
expect_true(any(grepl("Nothing to migrate", msg3)),
            info = "Empty repo emits a clear no-op message")
unlink(repo3, recursive = TRUE)

# ---- Case 4: Preview mode touches no files ----
repo4 <- tmp_repo()
cfg4 <- list(live_dir = file.path(repo4, "this_week"), indent = 2L)
src4 <- file.path(cfg4$live_dir, "todo_250915_daily.txt")
writeLines(c("# legacy", "", "[ ] - Pending"), src4)
src_mtime_before <- file.info(src4)$mtime

invisible(capture.output(
  pv <- hacer::migrate_to_markdown(cfg = cfg4, preview = TRUE),
  type = "message"
))
src_mtime_after <- file.info(src4)$mtime

expect_inherits(pv, "hacer_preview")
expect_identical(src_mtime_before, src_mtime_after,
                 info = "preview leaves source mtime untouched")
expect_false(file.exists(file.path(cfg4$live_dir, "todo_250915_daily.md")),
             info = "preview does not create the .md")
expect_true(file.exists(src4),
            info = "preview does not remove the .txt")
expect_equal(length(pv$files_created), 1L,
             info = "preview lists the one would-be-created .md")
unlink(repo4, recursive = TRUE)

# ---- Case 5: All four cadences migrate together ----
repo5 <- tmp_repo()
cfg5 <- list(live_dir = file.path(repo5, "this_week"), indent = 2L)
for (p in c("daily", "week", "month", "quarter")) {
  writeLines(
    c(paste0("# todo_250915_", p, ".txt"), "", "[ ] - Task"),
    file.path(cfg5$live_dir, paste0("todo_250915_", p, ".txt"))
  )
}
invisible(capture.output(
  hacer::migrate_to_markdown(cfg = cfg5),
  type = "message"
))
for (p in c("daily", "week", "month", "quarter")) {
  expect_true(file.exists(file.path(cfg5$live_dir, paste0("todo_250915_", p, ".md"))),
              info = paste("Migrated", p, "to .md"))
  expect_false(file.exists(file.path(cfg5$live_dir, paste0("todo_250915_", p, ".txt"))),
               info = paste("Removed", p, ".txt source"))
}
unlink(repo5, recursive = TRUE)
