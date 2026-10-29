# R/snapshot.R
# Single-file workflow: a hand-edited todo.md in live_dir, a dated copy per
# day, and a sweep of dated files from before this week into the archive.

# Date encoded in a dated todo filename, NA otherwise. Matches the snapshot
# form (todo_yymmdd.md) and the period forms (todo_yymmdd_daily.md,
# ToDo_yymmdd_Daily.txt, and their .html mirrors).
.dated_todo_date <- function(files) {
  b <- basename(files)
  m <- regmatches(b, regexec("^todo_([0-9]{6})(_[a-z]+)?\\.(md|txt|html)$",
                             b, ignore.case = TRUE))
  ds <- vapply(m, function(x) if (length(x)) x[2] else NA_character_, "")
  as.Date(ds, format = "%y%m%d")
}

# Run git in `dir`; args are passed to the shell, so quote paths/messages.
.git <- function(dir, ...) {
  suppressWarnings(system2("git", c("-C", shQuote(dir), ...),
                           stdout = TRUE, stderr = TRUE))
}

.git_failed <- function(out) !is.null(attr(out, "status"))

#' Snapshot the live todo file
#'
#' Copies `todo.md` to `todo_yymmdd.md` in `live_dir`, dated the day it
#' captures, then (by default) moves dated files from before this week into
#' the archive with [archive_old()]. Meant for an early-morning timer, so
#' the default `date` is yesterday: a run at 2am on Oct 29 writes
#' `todo_261028.md`. An existing dated file is left alone unless
#' `overwrite = TRUE`.
#'
#' @param date The day the snapshot captures. Defaults to yesterday.
#' @param cfg A config list from `todo_config()`.
#' @param overwrite If `TRUE`, replace an existing dated file.
#' @param archive If `TRUE` (default), sweep dated files older than
#'   `before` into `cfg$archive_dir`.
#' @param before Cutoff for the sweep. Defaults to this week's Monday.
#' @param commit If `TRUE`, commit the swept files; see [archive_old()].
#' @param push If `TRUE` (and `commit`), push after committing.
#' @param preview If `TRUE`, return a `hacer_preview` instead of writing.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @return The snapshot path, invisibly, or a `hacer_preview`.
#' @export
snapshot <- function(date = Sys.Date() - 1L, cfg = todo_config(),
                     overwrite = FALSE, archive = TRUE,
                     before = .monday_of(Sys.Date()),
                     commit = FALSE, push = FALSE,
                     preview = .preview_default()) {
  src <- todo_file(cfg)
  if (!file.exists(src)) stop("Todo file not found: ", src)
  date <- as.Date(date)
  dst <- file.path(cfg$live_dir, sprintf("todo_%s.md", format(date, "%y%m%d")))

  targets <- list()
  if (file.exists(dst) && !overwrite) {
    message("Snapshot exists, not overwriting: ", dst)
  } else {
    targets[[dst]] <- readLines(src, warn = FALSE)
  }
  result <- .write_or_preview(targets, preview)

  if (archive) {
    moved <- archive_old(cfg = cfg, before = before, commit = commit,
                         push = push, preview = preview)
    if (preview) result$files_moved <- moved$files_moved
  }
  if (!preview) return(invisible(dst))
  result
}

#' Move dated todo files from before a cutoff into the archive
#'
#' Looks in `cfg$live_dir` for dated files (`todo_yymmdd.md` snapshots and
#' the older `todo_yymmdd_<period>` forms) dated before `before` and moves
#' them to `cfg$archive_dir`. When the archive already has a file of that
#' name, the live copy is removed if the two are identical and left in
#' place with a warning otherwise.
#'
#' With `commit = TRUE`, the moved files are staged and committed in the
#' git repository that contains `archive_dir`. Only those paths are staged.
#' Nothing is committed when the archive isn't inside a repository.
#'
#' @param cfg A config list from `todo_config()`.
#' @param before A Date. Files dated before it are archived. Defaults to
#'   this week's Monday.
#' @param commit If `TRUE`, commit the moved files to the archive's repo.
#' @param push If `TRUE` (and `commit`), push after committing.
#' @param preview If `TRUE`, report the moves without touching anything.
#'   Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.
#' @return A data.frame of moves (`from`, `to`), invisibly, or a
#'   `hacer_preview` whose `files_moved` lists them.
#' @export
archive_old <- function(cfg = todo_config(), before = .monday_of(Sys.Date()),
                        commit = FALSE, push = FALSE,
                        preview = .preview_default()) {
  before <- as.Date(before)
  files <- list.files(cfg$live_dir, full.names = TRUE)
  dates <- .dated_todo_date(files)
  old <- files[!is.na(dates) & dates < before]
  moves <- data.frame(from = old,
                      to = file.path(cfg$archive_dir, basename(old)),
                      stringsAsFactors = FALSE)
  if (preview) {
    pv <- .new_preview()
    pv$files_moved <- moves
    return(pv)
  }
  if (!nrow(moves)) return(invisible(moves))

  dir.create(cfg$archive_dir, recursive = TRUE, showWarnings = FALSE)
  done <- logical(nrow(moves))
  for (i in seq_len(nrow(moves))) {
    done[i] <- .move_to_archive(moves$from[i], moves$to[i])
  }
  moves <- moves[done, , drop = FALSE]
  if (commit && nrow(moves)) .commit_archive(moves$to, before, push)
  invisible(moves)
}

# Move one file; dedupe against an identical archive copy. Returns TRUE
# when the archive now holds the file and the live copy is gone.
.move_to_archive <- function(from, to) {
  if (file.exists(to)) {
    same <- unname(tools::md5sum(from)) == unname(tools::md5sum(to))
    if (isTRUE(same)) {
      unlink(from)
      return(TRUE)
    }
    warning("Archive already has a different ", basename(to),
            "; left in place: ", from, call. = FALSE)
    return(FALSE)
  }
  ok <- file.rename(from, to)
  if (!ok) {
    ok <- file.copy(from, to) && file.remove(from)
  }
  if (!ok) warning("Could not move ", from, " to ", to, call. = FALSE)
  ok
}

.commit_archive <- function(paths, before, push = FALSE) {
  top <- .git(dirname(paths[1]), "rev-parse", "--show-toplevel")
  if (.git_failed(top) || !length(top)) {
    warning("Archive is not in a git repository; nothing committed",
            call. = FALSE)
    return(invisible(FALSE))
  }
  top <- top[1]
  q <- vapply(normalizePath(paths), shQuote, "")
  out <- .git(top, "add", "--", q)
  if (.git_failed(out)) {
    warning("git add failed:\n", paste(out, collapse = "\n"), call. = FALSE)
    return(invisible(FALSE))
  }
  msg <- paste("Archive todo files before", format(as.Date(before)))
  out <- .git(top, "commit", "-m", shQuote(msg), "--", q)
  if (.git_failed(out)) {
    warning("git commit failed:\n", paste(out, collapse = "\n"), call. = FALSE)
    return(invisible(FALSE))
  }
  if (push) {
    out <- .git(top, "push")
    if (.git_failed(out)) {
      warning("git push failed:\n", paste(out, collapse = "\n"), call. = FALSE)
      return(invisible(FALSE))
    }
  }
  invisible(TRUE)
}
