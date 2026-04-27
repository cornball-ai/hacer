# test_fix_parents.R - Tests for fix_parents() function

# Extract status character from any task line, regardless of legacy or markdown format.
status_of <- function(lines, task_label_regex) {
  i <- grep(task_label_regex, lines)
  if (!length(i)) return(NA_character_)
  m <- regmatches(lines[i[1]], regexec("\\[(.)\\]", lines[i[1]]))[[1]]
  if (length(m) >= 2L) m[2] else NA_character_
}

# Create temp Daily file (legacy .txt fixture; parser handles both formats)
tmpdir <- tempdir()
f <- file.path(tmpdir, "todo_250915_daily.txt")

# Case 1: child is in-progress -> parent should be '/'
lines_case1 <- c(
  "# todo_250915_daily.txt",
  "",
  "## Monday",
  "",
  "- [ ] House",
  "  - [/] Drywall Test",
  "",
  "## Tuesday",
  "",
  "- [ ] *Exercise"
)
writeLines(lines_case1, f)

hacer::fix_parents(file_name = f)
out1 <- readLines(f, warn = FALSE)

expect_equal(status_of(out1, "\\bHouse$"), "/",
             info = "Parent should roll to '/' when child is in-progress")

# Case 2: all children done -> parent should be 'x'
lines_case2 <- c(
  "# todo_250915_daily.txt",
  "",
  "## Monday",
  "",
  "- [ ] House",
  "  - [x] Drywall Test",
  "  - [x] Paint Trim",
  "",
  "## Tuesday",
  "",
  "- [ ] *Exercise"
)
writeLines(lines_case2, f)

hacer::fix_parents(file_name = f)
out2 <- readLines(f, warn = FALSE)

expect_equal(status_of(out2, "\\bHouse$"), "x",
             info = "Parent should roll to 'x' when all children are done")

# Cleanup
unlink(f)
