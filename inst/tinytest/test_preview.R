# test_preview.R - Tests for preview mode across mutators

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "archive"), recursive = TRUE, showWarnings = FALSE)
  d
}

cfg_for <- function(repo, indent = 2L) {
  list(live_dir = file.path(repo, "this_week"), indent = indent)
}

# ---- Case 1: fix_parents preview vs apply round trip ----
make_fp_repo <- function() {
  r <- tmp_repo()
  f <- file.path(r, "this_week", "todo_250915_daily.md")
  writeLines(c(
    "# todo_250915_daily.md",
    "",
    "#######################################",
    "",
    "# Monday",
    "",
    "[ ] - House",
    "  [/] - Drywall",
    "  [x] - Trim"
  ), f)
  list(repo = r,
       file = f)
}

fp_a <- make_fp_repo()
hacer::fix_parents(fp_a$file, preview = FALSE)
state_fp_a <- readLines(fp_a$file, warn = FALSE)

fp_b <- make_fp_repo()
mtime_before <- file.info(fp_b$file)$mtime
pv1 <- hacer::fix_parents(fp_b$file, preview = TRUE)
mtime_after <- file.info(fp_b$file)$mtime
expect_identical(mtime_before, mtime_after,
                 info = "fix_parents preview leaves mtime untouched")
expect_inherits(pv1, "hacer_preview")
expect_equal(length(pv1$files_modified), 1L,
             info = "fix_parents preview reports one modified file")

hacer:::.apply_preview(pv1)
state_fp_b <- readLines(fp_b$file, warn = FALSE)
expect_identical(state_fp_a, state_fp_b,
                 info = "fix_parents preview + apply matches non-preview")

unlink(fp_a$repo, recursive = TRUE)
unlink(fp_b$repo, recursive = TRUE)

# ---- Case 2: instantiate_todo preview lists files but creates none ----
repo2 <- tempfile()
pv2 <- hacer::instantiate_todo(repo2, preview = TRUE)
expect_inherits(pv2, "hacer_preview")
expect_false(dir.exists(repo2),
             info = "instantiate_todo preview does not create the repo dir")
expect_true(length(pv2$files_created) >= 5L,
            info = "Preview lists at least the seed + config files (>= 5)")

hacer:::.apply_preview(pv2)
expect_true(dir.exists(repo2),
            info = "Applying the preview creates the directory")
expect_true(file.exists(file.path(repo2, "hacer_config.R")),
            info = "Config file exists after apply")
expect_true(file.exists(file.path(repo2, "README_HACER.md")),
            info = "README exists after apply")
unlink(repo2, recursive = TRUE)

# ---- Case 3: sync_from_daily preview round-trip ----
make_sync_repo <- function() {
  r <- tmp_repo()
  mon <- "250915"
  for (p in c("Daily", "Week", "Month", "Quarter")) {
    f <- file.path(r, "this_week",
                   sprintf("todo_%s_%s.txt", mon, tolower(p)))
    writeLines(c(
      paste0("# todo_", mon, "_", tolower(p), ".txt"),
      "",
      "#######################################",
      "",
      "[ ] - Existing"
    ), f)
  }
  # Add a brand-new task only to Daily
  daily <- file.path(r, "this_week", paste0("todo_", mon, "_daily.md"))
  writeLines(c(
    paste0("# todo_", mon, "_daily.md"),
    "",
    "#######################################",
    "",
    "[ ] - Existing",
    "[ ] - Brand new task"
  ), daily)
  r
}

sync_a <- make_sync_repo()
hacer::sync_from_daily(date = as.Date("2025-09-15"),
                       cfg = cfg_for(sync_a), preview = FALSE)
state_sync_a <- lapply(c("week","month","quarter"), function(p) {
  readLines(file.path(sync_a, "this_week", paste0("todo_250915_", p, ".txt")),
            warn = FALSE)
})

sync_b <- make_sync_repo()
pv3 <- hacer::sync_from_daily(date = as.Date("2025-09-15"),
                              cfg = cfg_for(sync_b), preview = TRUE)
expect_inherits(pv3, "hacer_preview")
hacer:::.apply_preview(pv3)
state_sync_b <- lapply(c("week","month","quarter"), function(p) {
  readLines(file.path(sync_b, "this_week", paste0("todo_250915_", p, ".txt")),
            warn = FALSE)
})
expect_identical(state_sync_a, state_sync_b,
                 info = "sync_from_daily preview + apply matches non-preview")
unlink(sync_a, recursive = TRUE)
unlink(sync_b, recursive = TRUE)
