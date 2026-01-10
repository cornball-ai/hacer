# ---- helpers ----
library(todoengine)
read_trim <- function(f) trimws(readLines(f, warn = FALSE), which = "right")
status_of <- function(lines, task_label_regex) {
  # find first matching line like "[x] - House"
  i <- grep(paste0("^\\[( |/|x)\\]\\s+-\\s", task_label_regex, "$"), lines)
  if (!length(i)) return(NA_character_)
  substr(lines[i[1]], 2, 2)  # " ", "/", or "x"
}

# ---- make a temp Daily file ending with _Daily.txt ----
tmpdir <- tempdir()
f <- file.path(tmpdir, "ToDo_250915_Daily.txt")

# ---- Case 1: child is in-progress -> parent should be '/' ----
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

# call your exported function (argument name = file_name)
todoengine::fix_parents(file_name = f)

out1 <- read_trim(f)
stopifnot(identical(status_of(out1, "House"), "/"))
cat("Case 1 OK: parent rolled to '/'\n")

# ---- Case 2: all children done -> parent should be 'x' ----
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

todoengine::fix_parents(file_name = f)

out2 <- read_trim(f)
stopifnot(identical(status_of(out2, "House"), "x"))
cat("Case 2 OK: parent rolled to 'x'\n")

cat("All fix_parents() tests passed.\n")
