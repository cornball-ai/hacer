# Tests for mirror_subtree(): subtree translation + additive merge.

library(hacer)
library(tinytest)

wk <- function(lines) {
  d <- tempfile(fileext = ".md")
  writeLines(lines, d)
  d
}

# Source (cornelius-like): company work under "Troy > cornball.ai", plus a
# Jorge subtree that must never be touched.
src <- wk(c(
  "# wk",
  "",
  "- [ ] Troy",
  "  - [ ] cornball.ai",
  "    - [x] OSS",
  "    - [ ] NewThing",
  "- [ ] Jorge",
  "  - [ ] jorge stuff"
))

# Target (tiny-like): top-level cornball.ai with a personal-only note.
tgt <- wk(c(
  "# wk",
  "",
  "- [ ] cornball.ai",
  "  - [ ] OSS",
  "  - [ ] PersonalNote",
  "- [ ] House"
))

mirror_subtree(src, tgt, "Troy > cornball.ai", "cornball.ai",
               period = "Week", conflict = "source", preview = FALSE)

res <- parse_todo(tgt, "Week")

# source-only path added, translated to the target's top-level breadcrumb
expect_true("cornball.ai > NewThing" %in% res$path)

# shared path took the SOURCE status ([x] from cornelius)
expect_equal(res$status[res$path == "cornball.ai > OSS"], "x")

# target-only path preserved
expect_true("cornball.ai > PersonalNote" %in% res$path)

# item outside the subtree untouched
expect_true("House" %in% res$path)

# Jorge subtree never leaked into the target
expect_false(any(grepl("Jorge", res$path)))
expect_false(any(grepl("jorge stuff", res$name)))

# new item nests correctly (level 1 under cornball.ai)
expect_equal(res$level[res$path == "cornball.ai > NewThing"], 1L)

# ---- conflict = "target" keeps the target's status ----
tgt2 <- wk(c("# wk", "", "- [ ] cornball.ai", "  - [/] OSS"))
mirror_subtree(src, tgt2, "Troy > cornball.ai", "cornball.ai",
               period = "Week", conflict = "target", preview = FALSE)
res2 <- parse_todo(tgt2, "Week")
expect_equal(res2$status[res2$path == "cornball.ai > OSS"], "/")

# ---- empty source subtree is a no-op ----
tgt3 <- wk(c("# wk", "", "- [ ] cornball.ai", "  - [ ] OSS"))
before <- readLines(tgt3)
mirror_subtree(src, tgt3, "Nonexistent > path", "cornball.ai",
               period = "Week", preview = FALSE)
expect_equal(readLines(tgt3), before)

# ---- preview writes nothing, reports planned changes ----
tgt4 <- wk(c("# wk", "", "- [ ] cornball.ai", "  - [ ] OSS"))
before4 <- readLines(tgt4)
plan <- mirror_subtree(src, tgt4, "Troy > cornball.ai", "cornball.ai",
                       period = "Week", conflict = "source", preview = TRUE)
expect_equal(readLines(tgt4), before4)
expect_true("cornball.ai > NewThing" %in% plan$added)

# ---- breadcrumb helpers ----
expect_equal(hacer:::.path_parent("A > B > C"), "A > B")
expect_true(is.na(hacer:::.path_parent("A")))
expect_equal(hacer:::.path_leaf("A > B > C"), "C")
expect_equal(hacer:::.path_level("A > B > C"), 2L)
expect_equal(hacer:::.path_level("A"), 0L)

# path-into-deeper-target: mirror tiny's top-level up into a nested parent
src5 <- wk(c("# wk", "", "- [ ] cornball.ai", "  - [ ] OSS"))
tgt5 <- wk(c("# wk", "", "- [ ] Troy"))
mirror_subtree(src5, tgt5, "cornball.ai", "Troy > cornball.ai",
               period = "Week", conflict = "source", preview = FALSE)
res5 <- parse_todo(tgt5, "Week")
expect_true("Troy > cornball.ai > OSS" %in% res5$path)
expect_equal(res5$level[res5$path == "Troy > cornball.ai > OSS"], 2L)
