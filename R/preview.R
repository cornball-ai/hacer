# R/preview.R
# Preview-mode plumbing: every mutator can return a `hacer_preview` object
# describing what would change instead of writing to disk. Set the env var
# HACER_PREVIEW=1 to flip the default for the whole session / one-shot CLI.

.preview_default <- function() {
  v <- Sys.getenv("HACER_PREVIEW", unset = "")
  v %in% c("1", "true", "TRUE", "yes", "YES")
}

.empty_diff_df <- function() {
  data.frame(file = character(), line = integer(), text = character(),
             stringsAsFactors = FALSE)
}

.new_preview <- function() {
  obj <- list(
    files_created    = character(),
    files_modified   = character(),
    lines_added      = .empty_diff_df(),
    lines_removed    = .empty_diff_df(),
    done_log_appends = character()
  )
  attr(obj, "targets") <- list()       # named list: path -> new lines
  attr(obj, "done_log_path") <- NA_character_
  class(obj) <- "hacer_preview"
  obj
}

# LCS-based line diff. Returns added/removed data.frames keyed to `file`.
.line_diff <- function(old, new, file) {
  added <- list(); removed <- list()
  if (!length(old) && !length(new)) {
    return(list(added = .empty_diff_df(), removed = .empty_diff_df()))
  }
  if (!length(old)) {
    return(list(
      added = data.frame(file = file, line = seq_along(new), text = new,
                         stringsAsFactors = FALSE),
      removed = .empty_diff_df()
    ))
  }
  if (!length(new)) {
    return(list(
      added = .empty_diff_df(),
      removed = data.frame(file = file, line = seq_along(old), text = old,
                           stringsAsFactors = FALSE)
    ))
  }
  m <- length(old); n <- length(new)
  L <- matrix(0L, m + 1L, n + 1L)
  for (i in seq_len(m)) {
    ai <- old[i]
    for (j in seq_len(n)) {
      if (identical(ai, new[j])) L[i + 1L, j + 1L] <- L[i, j] + 1L
      else L[i + 1L, j + 1L] <- max(L[i, j + 1L], L[i + 1L, j])
    }
  }
  i <- m; j <- n
  while (i > 0L || j > 0L) {
    if (i > 0L && j > 0L && identical(old[i], new[j])) {
      i <- i - 1L; j <- j - 1L
    } else if (j > 0L && (i == 0L || L[i + 1L, j] >= L[i, j + 1L])) {
      added[[length(added) + 1L]] <- data.frame(
        file = file, line = j, text = new[j], stringsAsFactors = FALSE)
      j <- j - 1L
    } else {
      removed[[length(removed) + 1L]] <- data.frame(
        file = file, line = i, text = old[i], stringsAsFactors = FALSE)
      i <- i - 1L
    }
  }
  list(
    added = if (length(added))
      do.call(rbind, rev(added)) else .empty_diff_df(),
    removed = if (length(removed))
      do.call(rbind, rev(removed)) else .empty_diff_df()
  )
}

# Take a list of (path -> new lines) plus optional done.log appends and
# either write everything to disk (preview = FALSE) or return a hacer_preview.
.write_or_preview <- function(targets,
                              preview,
                              done_log_path = NA_character_,
                              done_log_appends = character()) {
  if (!preview) {
    for (path in names(targets)) {
      dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
      writeLines(targets[[path]], path)
    }
    if (length(done_log_appends) && !is.na(done_log_path)) {
      if (file.exists(done_log_path)) {
        cat(paste0(done_log_appends, "\n"),
            file = done_log_path, append = TRUE, sep = "")
      } else {
        writeLines(done_log_appends, done_log_path)
      }
    }
    return(invisible(names(targets)))
  }

  pv <- .new_preview()
  for (path in names(targets)) {
    new_lines <- targets[[path]]
    if (!file.exists(path)) {
      pv$files_created <- c(pv$files_created, path)
      if (length(new_lines)) {
        pv$lines_added <- rbind(pv$lines_added, data.frame(
          file = path, line = seq_along(new_lines), text = new_lines,
          stringsAsFactors = FALSE))
      }
    } else {
      old_lines <- readLines(path, warn = FALSE)
      if (!identical(old_lines, new_lines)) {
        pv$files_modified <- c(pv$files_modified, path)
        d <- .line_diff(old_lines, new_lines, path)
        pv$lines_added   <- rbind(pv$lines_added,   d$added)
        pv$lines_removed <- rbind(pv$lines_removed, d$removed)
      }
    }
  }
  pv$done_log_appends <- done_log_appends
  attr(pv, "targets") <- targets
  attr(pv, "done_log_path") <- done_log_path
  pv
}

# Apply a preview to disk. Mainly used by tests to verify that a preview
# round-trips to the same end state as a non-preview call. Internal.
.apply_preview <- function(pv) {
  targets <- attr(pv, "targets")
  for (path in names(targets)) {
    dir.create(dirname(path), recursive = TRUE, showWarnings = FALSE)
    writeLines(targets[[path]], path)
  }
  done_log_path <- attr(pv, "done_log_path")
  if (length(pv$done_log_appends) && !is.na(done_log_path)) {
    if (file.exists(done_log_path)) {
      cat(paste0(pv$done_log_appends, "\n"),
          file = done_log_path, append = TRUE, sep = "")
    } else {
      writeLines(pv$done_log_appends, done_log_path)
    }
  }
  invisible(names(targets))
}

#' Print a hacer_preview summary
#'
#' @param x A `hacer_preview` object.
#' @param ... Unused.
#' @export
print.hacer_preview <- function(x, ...) {
  cat("hacer preview\n")
  if (length(x$files_created)) {
    cat("  created (", length(x$files_created), "):\n", sep = "")
    for (f in x$files_created) cat("    + ", f, "\n", sep = "")
  }
  if (length(x$files_modified)) {
    cat("  modified (", length(x$files_modified), "):\n", sep = "")
    for (f in x$files_modified) {
      n_add <- sum(x$lines_added$file == f)
      n_rm  <- sum(x$lines_removed$file == f)
      cat("    ~ ", f, " (+", n_add, "/-", n_rm, ")\n", sep = "")
    }
  }
  if (length(x$done_log_appends)) {
    cat("  done.log appends (", length(x$done_log_appends), "):\n", sep = "")
    for (ln in x$done_log_appends) cat("    > ", ln, "\n", sep = "")
  }
  if (!length(x$files_created) && !length(x$files_modified) &&
      !length(x$done_log_appends)) {
    cat("  (no changes)\n")
  }
  invisible(x)
}
