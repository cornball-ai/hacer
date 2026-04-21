# test_fix_parents.R - Tests for fix_parents() function

# Helper to extract status from a task line
status_of <- function(lines, task_label_regex) {
  i <- grep(paste0("^\\[( |/|x)\\]\\s+-\\s*", task_label_regex), lines)
  if (!length(i)) return(NA_character_)
  substr(lines[i[1]], 2, 2)
}

# Create temp Daily file
tmpdir <- tempdir()
f <- file.path(tmpdir, "ToDo_250915_Daily.txt")

# Case 1: child is in-progress -> parent should be '/'
lines_case1 <- c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "# Monday",
  "",
  "[ ] - House",
  "  [/] - Drywall Test",
  "",
  "#######################################",
  "",
  "# Tuesday",
  "",
  "[ ] -*Exercise"
)
writeLines(lines_case1, f)

hacer::fix_parents(file_name = f)
out1 <- readLines(f, warn = FALSE)

expect_equal(status_of(out1, "House"), "/",
             info = "Parent should roll to '/' when child is in-progress")

# Case 2: all children done -> parent should be 'x'
lines_case2 <- c(
  "# ToDo_250915_Daily.txt",
  "",
  "#######################################",
  "",
  "# Monday",
  "",
  "[ ] - House",
  "  [x] - Drywall Test",
  "  [x] - Paint Trim",
  "",
  "#######################################",
  "",
  "# Tuesday",
  "",
  "[ ] -*Exercise"
)
writeLines(lines_case2, f)

hacer::fix_parents(file_name = f)
out2 <- readLines(f, warn = FALSE)

expect_equal(status_of(out2, "House"), "x",
             info = "Parent should roll to 'x' when all children are done")

# Cleanup
unlink(f)
