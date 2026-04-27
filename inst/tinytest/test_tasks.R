# test_tasks.R - Tests for tasks() data.frame API

library(hacer)

tmp_repo <- function() {
  d <- tempfile()
  dir.create(file.path(d, "this_week"), recursive = TRUE, showWarnings = FALSE)
  d
}

# ---- Case 1: Column shape and types match the spec ----
repo1 <- tmp_repo()
cfg1 <- list(live_dir = file.path(repo1, "this_week"), indent = 2L)

f1 <- file.path(cfg1$live_dir, "todo_250915_daily.md")
writeLines(c(
  "# todo_250915_daily.md",
  "",
  "#######################################",
  "",
  "# Monday",
  "",
  "[ ] - Top todo",
  "  [/] - Sub in progress",
  "  [x] - Sub done",
  "[ ] -*Recurring",
  "[!] - Blocked one"
), f1)

df1 <- tasks(cfg = cfg1)

expect_equal(
  names(df1),
  c("id", "file", "line", "depth", "status", "recurring", "text", "parent_id"),
  info = "Columns must match the spec exactly and in order"
)
expect_true(is.character(df1$id),        info = "id is character")
expect_true(is.character(df1$file),      info = "file is character")
expect_true(is.integer(df1$line),        info = "line is integer")
expect_true(is.integer(df1$depth),       info = "depth is integer")
expect_true(is.character(df1$status),    info = "status is character")
expect_true(is.logical(df1$recurring),   info = "recurring is logical")
expect_true(is.character(df1$text),      info = "text is character")
expect_true(is.character(df1$parent_id), info = "parent_id is character")

expect_equal(nrow(df1), 5L, info = "Five tasks parsed")
expect_equal(df1$status,
             c("todo", "in_progress", "done", "todo", "blocked"),
             info = "Status mapping for [ ], [/], [x], [!]")
expect_equal(df1$recurring, c(FALSE, FALSE, FALSE, TRUE, FALSE),
             info = "Recurring flag set only on starred task")
expect_equal(df1$text,
             c("Top todo", "Sub in progress", "Sub done",
               "Recurring", "Blocked one"),
             info = "Text strips status, dash, recurring marker")
expect_equal(df1$file,
             rep("todo_250915_daily.md", 5L),
             info = "file column is the basename")
expect_equal(df1$depth, c(0L, 1L, 1L, 0L, 0L),
             info = "Depth derived from leading-space count")

# Round trip: same parse, same IDs
df1_again <- tasks(cfg = cfg1)
expect_identical(df1, df1_again,
                 info = "Parsing the same file twice yields identical IDs")

unlink(repo1, recursive = TRUE)

# ---- Case 2: parent_id resolves across 3+ levels of nesting ----
repo2 <- tmp_repo()
cfg2 <- list(live_dir = file.path(repo2, "this_week"), indent = 2L)

f2 <- file.path(cfg2$live_dir, "todo_250915_daily.md")
writeLines(c(
  "# todo_250915_daily.md",
  "",
  "#######################################",
  "",
  "[ ] - L0",
  "  [ ] - L1",
  "    [ ] - L2",
  "      [ ] - L3",
  "  [ ] - L1b"
), f2)

df2 <- tasks(cfg = cfg2)

expect_equal(df2$depth, c(0L, 1L, 2L, 3L, 1L),
             info = "Depths span 0..3")
# Root has NA parent
expect_true(is.na(df2$parent_id[df2$text == "L0"]),
            info = "Root task has NA parent_id")
# Each child points at the immediately shallower ancestor
expect_equal(df2$parent_id[df2$text == "L1"],
             df2$id[df2$text == "L0"],
             info = "L1 parent is L0")
expect_equal(df2$parent_id[df2$text == "L2"],
             df2$id[df2$text == "L1"],
             info = "L2 parent is L1")
expect_equal(df2$parent_id[df2$text == "L3"],
             df2$id[df2$text == "L2"],
             info = "L3 parent is L2")
# Sibling at L1 after a deep descent points back to the right parent
expect_equal(df2$parent_id[df2$text == "L1b"],
             df2$id[df2$text == "L0"],
             info = "Dedented sibling resolves to the correct parent, not L2")

unlink(repo2, recursive = TRUE)

# ---- Case 3: Filter args produce correct subsets ----
repo3 <- tmp_repo()
cfg3 <- list(live_dir = file.path(repo3, "this_week"), indent = 2L)

f3 <- file.path(cfg3$live_dir, "todo_250915_daily.md")
writeLines(c(
  "# todo_250915_daily.md",
  "",
  "[ ] - todo a",
  "[/] - in progress a",
  "[x] - done a",
  "[!] - blocked a",
  "[ ] -*recurring a",
  "[x] -*recurring done"
), f3)

# status filter
expect_equal(nrow(tasks(cfg = cfg3, status = "todo")), 2L,
             info = "status='todo' returns the two [ ] rows")
expect_equal(nrow(tasks(cfg = cfg3, status = c("done", "blocked"))), 3L,
             info = "Vector status filter unions matches")

# recurring filter
expect_equal(nrow(tasks(cfg = cfg3, recurring = TRUE)), 2L,
             info = "recurring=TRUE returns the two starred rows")
expect_equal(nrow(tasks(cfg = cfg3, recurring = FALSE)), 4L,
             info = "recurring=FALSE returns the four non-starred rows")

# blocked convenience
expect_equal(nrow(tasks(cfg = cfg3, blocked = TRUE)), 1L,
             info = "blocked=TRUE returns the one [!] row")
expect_equal(nrow(tasks(cfg = cfg3, blocked = FALSE)), 5L,
             info = "blocked=FALSE returns everything else")

# Combined filters intersect
expect_equal(
  nrow(tasks(cfg = cfg3, status = "done", recurring = TRUE)),
  1L,
  info = "status + recurring intersect"
)

unlink(repo3, recursive = TRUE)

# ---- Case 4: Multi-file parse merges across all this_week files ----
repo4 <- tmp_repo()
cfg4 <- list(live_dir = file.path(repo4, "this_week"), indent = 2L)

for (p in c("Daily", "Week", "Month", "Quarter")) {
  f <- file.path(cfg4$live_dir,
                 sprintf("todo_250915_%s.md", tolower(p)))
  writeLines(c(
    paste0("# todo_250915_", tolower(p), ".md"),
    "",
    "- [ ] One per file"
  ), f)
}

df4 <- tasks(cfg = cfg4)
expect_equal(nrow(df4), 4L, info = "All four cadence files contribute one row each")
expect_equal(sort(unique(df4$file)),
             sort(paste0("todo_250915_",
                         c("daily", "month", "quarter", "week"), ".md")),
             info = "file column reflects the source basename")

# Single-file argument scopes to that file only
df4_one <- tasks(file = file.path(cfg4$live_dir, "todo_250915_daily.md"),
                 cfg = cfg4)
expect_equal(nrow(df4_one), 1L, info = "Single-file arg parses only that file")
expect_equal(df4_one$file, "todo_250915_daily.md",
             info = "Single-file arg returns matching basename")

unlink(repo4, recursive = TRUE)

# ---- Case 5: Empty live_dir yields an empty data.frame, not an error ----
repo5 <- tmp_repo()
cfg5 <- list(live_dir = file.path(repo5, "this_week"), indent = 2L)

df5 <- tasks(cfg = cfg5)
expect_equal(nrow(df5), 0L, info = "Empty live_dir returns zero-row data.frame")
expect_equal(
  names(df5),
  c("id", "file", "line", "depth", "status", "recurring", "text", "parent_id"),
  info = "Empty result still has the full column set"
)

unlink(repo5, recursive = TRUE)

# ---- Case 6: Missing file argument errors clearly ----
expect_error(
  tasks(file = "/no/such/path/todo_250915_daily.md"),
  pattern = "not found",
  info = "Non-existent file path errors with a clear message"
)

# ---- Case 7: Line numbers are 1-indexed and match the source ----
repo7 <- tmp_repo()
cfg7 <- list(live_dir = file.path(repo7, "this_week"), indent = 2L)

f7 <- file.path(cfg7$live_dir, "todo_250915_daily.md")
writeLines(c(
  "# header",                 # 1
  "",                         # 2
  "[ ] - first",              # 3
  "",                         # 4
  "  [/] - second indented"   # 5
), f7)

df7 <- tasks(cfg = cfg7)
expect_equal(df7$line, c(3L, 5L), info = "Line numbers point at the actual source line")
expect_true(grepl(":L3$", df7$id[1]), info = "id encodes the line number")
expect_true(grepl(":L5$", df7$id[2]), info = "id encodes the line number")

unlink(repo7, recursive = TRUE)
