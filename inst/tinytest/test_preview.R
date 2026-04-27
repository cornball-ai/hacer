# test_preview.R - Tests for preview mode across all mutators

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  dir.create(file.path(d, "archive"), recursive = TRUE, showWarnings = FALSE)
  d
}

mtimes_in <- function(dir) {
  fs <- list.files(dir, recursive = TRUE, full.names = TRUE)
  setNames(file.info(fs)$mtime, fs)
}

# ---- Helper: roll_day round-trip preview vs apply ----
cfg_for <- function(repo, indent = 2L) {
  list(live_dir = file.path(repo, "this_week"), indent = indent)
}

# ---- Case 1: roll_day(preview=TRUE) writes nothing ----
repo1 <- tmp_repo()
cfg1 <- cfg_for(repo1)
f1 <- file.path(cfg1$live_dir, "todo_250915_daily.txt")
writeLines(c(
  "# todo_250915_daily.txt",
  "",
  "[ ] - Pending",
  "[x] - Done"
), f1)

before_mtimes <- mtimes_in(repo1)
pv1 <- hacer::roll_day(date = as.Date("2025-09-16"), cfg = cfg1, preview = TRUE)
after_mtimes <- mtimes_in(repo1)

expect_inherits(pv1, "hacer_preview",
                info = "preview=TRUE returns a hacer_preview")
expect_identical(before_mtimes, after_mtimes,
                 info = "preview=TRUE leaves on-disk mtimes untouched")
expect_false(file.exists(file.path(cfg1$live_dir, "todo_250916_daily.txt")),
             info = "preview=TRUE does not create new files")
expect_false(file.exists(file.path(repo1, "done.log")),
             info = "preview=TRUE does not create done.log")

# Preview reports the would-be changes
expect_equal(length(pv1$files_created), 1L,
             info = "Preview lists one new file")
expect_true(grepl("todo_250916_daily\\.txt$", pv1$files_created[1]),
            info = "Preview names the new daily file")
expect_equal(length(pv1$done_log_appends), 1L,
             info = "Preview lists one done.log append")
expect_true(grepl("Done", pv1$done_log_appends[1]),
            info = "done.log append captures the dropped task text")

unlink(repo1, recursive = TRUE)

# ---- Case 2: roll_day preview + apply == roll_day non-preview ----
make_repo <- function() {
  r <- tmp_repo()
  f <- file.path(r, "this_week", "todo_250915_daily.txt")
  writeLines(c(
    "# todo_250915_daily.txt",
    "",
    "#######################################",
    "",
    "# Monday",
    "",
    "[ ] - House",
    "  [/] - Drywall",
    "  [x] - Trim",
    "[ ] -*Exercise",
    "[x] - One-time"
  ), f)
  r
}

repo_a <- make_repo()
hacer::roll_day(date = as.Date("2025-09-16"),
                cfg = cfg_for(repo_a),
                preview = FALSE)
state_a <- list(
  daily = readLines(file.path(repo_a, "this_week", "todo_250916_daily.txt"),
                    warn = FALSE),
  done  = readLines(file.path(repo_a, "done.log"), warn = FALSE)
)

repo_b <- make_repo()
pv2 <- hacer::roll_day(date = as.Date("2025-09-16"),
                      cfg = cfg_for(repo_b),
                      preview = TRUE)
hacer:::.apply_preview(pv2)
state_b <- list(
  daily = readLines(file.path(repo_b, "this_week", "todo_250916_daily.txt"),
                    warn = FALSE),
  done  = readLines(file.path(repo_b, "done.log"), warn = FALSE)
)

expect_identical(state_a$daily, state_b$daily,
                 info = "preview + apply produces same Daily file as direct roll")
expect_identical(state_a$done, state_b$done,
                 info = "preview + apply produces same done.log as direct roll")

unlink(repo_a, recursive = TRUE)
unlink(repo_b, recursive = TRUE)

# ---- Case 3: HACER_PREVIEW env var flips the default ----
repo3 <- tmp_repo()
cfg3 <- cfg_for(repo3)
f3 <- file.path(cfg3$live_dir, "todo_250915_daily.txt")
writeLines(c("# todo_250915_daily.txt", "", "[ ] - Task"), f3)

old_env <- Sys.getenv("HACER_PREVIEW", unset = NA)
Sys.setenv(HACER_PREVIEW = "1")
pv3 <- hacer::roll_day(date = as.Date("2025-09-16"), cfg = cfg3)
expect_inherits(pv3, "hacer_preview",
                info = "HACER_PREVIEW=1 flips the default to preview mode")
expect_false(file.exists(file.path(cfg3$live_dir, "todo_250916_daily.txt")),
             info = "HACER_PREVIEW=1 still writes nothing")

Sys.setenv(HACER_PREVIEW = "")
out3 <- hacer::roll_day(date = as.Date("2025-09-16"), cfg = cfg3)
expect_false(inherits(out3, "hacer_preview"),
             info = "Empty HACER_PREVIEW restores the write default")
expect_true(file.exists(file.path(cfg3$live_dir, "todo_250916_daily.txt")),
            info = "Empty HACER_PREVIEW writes as before")

if (is.na(old_env)) Sys.unsetenv("HACER_PREVIEW") else Sys.setenv(HACER_PREVIEW = old_env)
unlink(repo3, recursive = TRUE)

# ---- Case 4: print.hacer_preview renders a sensible summary ----
repo4 <- tmp_repo()
cfg4 <- cfg_for(repo4)
f4 <- file.path(cfg4$live_dir, "todo_250915_daily.txt")
writeLines(c("# todo_250915_daily.txt", "", "[ ] - Task", "[x] - Done"), f4)

pv4 <- hacer::roll_day(date = as.Date("2025-09-16"), cfg = cfg4, preview = TRUE)
out4 <- capture.output(print(pv4))
combined4 <- paste(out4, collapse = "\n")
expect_true(grepl("hacer preview", combined4),
            info = "Print method labels itself")
expect_true(grepl("created", combined4),
            info = "Print mentions created files")
expect_true(grepl("done\\.log", combined4),
            info = "Print mentions done.log appends")
unlink(repo4, recursive = TRUE)

# ---- Case 5: fix_parents preview vs apply round trip ----
make_fp_repo <- function() {
  r <- tmp_repo()
  f <- file.path(r, "this_week", "todo_250915_daily.txt")
  writeLines(c(
    "# todo_250915_daily.txt",
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
pv5 <- hacer::fix_parents(fp_b$file, preview = TRUE)
mtime_after <- file.info(fp_b$file)$mtime
expect_identical(mtime_before, mtime_after,
                 info = "fix_parents preview leaves mtime untouched")
expect_inherits(pv5, "hacer_preview")
expect_equal(length(pv5$files_modified), 1L,
             info = "fix_parents preview reports one modified file")

hacer:::.apply_preview(pv5)
state_fp_b <- readLines(fp_b$file, warn = FALSE)
expect_identical(state_fp_a, state_fp_b,
                 info = "fix_parents preview + apply matches non-preview")

unlink(fp_a$repo, recursive = TRUE)
unlink(fp_b$repo, recursive = TRUE)

# ---- Case 6: instantiate_todo preview lists files but creates none ----
repo6 <- tempfile()
pv6 <- hacer::instantiate_todo(repo6, preview = TRUE)
expect_inherits(pv6, "hacer_preview")
expect_false(dir.exists(repo6),
             info = "instantiate_todo preview does not create the repo dir")
expect_true(length(pv6$files_created) >= 5L,
            info = "Preview lists at least the seed + config files (>= 5)")

# Apply the preview and verify everything materialized
hacer:::.apply_preview(pv6)
expect_true(dir.exists(repo6),
            info = "Applying the preview creates the directory")
expect_true(file.exists(file.path(repo6, "hacer_config.R")),
            info = "Config file exists after apply")
expect_true(file.exists(file.path(repo6, "README_HACER.md")),
            info = "README exists after apply")
unlink(repo6, recursive = TRUE)

# ---- Case 7: roll_day on empty repo returns empty preview, not error ----
repo7 <- tmp_repo()
pv7 <- hacer::roll_day(date = as.Date("2025-09-16"),
                       cfg = cfg_for(repo7),
                       preview = TRUE)
expect_inherits(pv7, "hacer_preview")
expect_equal(length(pv7$files_created), 0L,
             info = "Empty repo preview has no created files")
expect_equal(length(pv7$files_modified), 0L,
             info = "Empty repo preview has no modified files")
unlink(repo7, recursive = TRUE)

# ---- Case 8: sync_from_daily preview round-trip ----
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
  daily <- file.path(r, "this_week", paste0("todo_", mon, "_daily.txt"))
  writeLines(c(
    paste0("# todo_", mon, "_daily.txt"),
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
pv8 <- hacer::sync_from_daily(date = as.Date("2025-09-15"),
                              cfg = cfg_for(sync_b), preview = TRUE)
expect_inherits(pv8, "hacer_preview")
hacer:::.apply_preview(pv8)
state_sync_b <- lapply(c("week","month","quarter"), function(p) {
  readLines(file.path(sync_b, "this_week", paste0("todo_250915_", p, ".txt")),
            warn = FALSE)
})
expect_identical(state_sync_a, state_sync_b,
                 info = "sync_from_daily preview + apply matches non-preview")
unlink(sync_a, recursive = TRUE)
unlink(sync_b, recursive = TRUE)
