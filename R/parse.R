# R/parse.R
# returns a data.frame: id, parent_id, period, section, name, recur, status, level, order, path
#' @export
parse_todo <- function(file, period = NA_character_, indent = NULL) {
  if (is.null(indent)) indent <- todo_config()$indent
  if (!file.exists(file)) stop("Missing file: ", file)
  lines <- readLines(file, warn = FALSE)
  out <- vector("list", length(lines))
  sec <- NA_character_
  ord <- 0L
  stk_ids <- character(32L) # stack by level
  stk_paths <- character(32L)
  
  make_row <- function(level, section, name, recur, status, order, parent_id, path) {
    list(
      id = paste0(path), parent_id = parent_id, period = period, section = section,
      name = name, recur = recur, status = status, level = level,
      order = order, path = path
    )
  }
  
  n <- 0L
  for (ln in lines) {
    if (grepl("^# ", ln)) {                  # section header
      sec <- sub("^#\\s*", "", ln)
      next
    }
    # task lines look like: "  [x] - *HAss"  or "  [ ] - Second Floor"
    stripped <- sub("^\\s+", "", ln)
    if (!grepl("^\\[( |/|x)\\]\\s*-", stripped)) next
    
    # level by leading spaces
    nspaces <- nchar(ln) - nchar(stripped)
    level <- as.integer(nspaces / indent)
    
    # status
    status <- substr(stripped, 2L, 2L)   # " ", "/", or "x"
    
    # after ] -, detect optional '*' tight or spaced
    rest <- sub("^\\[( |/|x)\\]\\s*-\\s*", "", stripped)
    recur <- FALSE
    if (grepl("^\\*", rest)) {
      recur <- TRUE
      rest <- sub("^\\*", "", rest)
    }
    name <- trimws(rest)
    
    # parent tracking by level
    if (level == 0L) {
      parent_id <- NA_character_
      path <- name
    } else {
      parent_id <- stk_ids[level]
      base_path <- stk_paths[level]
      if (is.na(base_path) || base_path == "") base_path <- ""
      path <- if (base_path == "") name else paste(base_path, name, sep = " > ")
    }
    # set this node as the parent for next deeper level
    stk_ids[level + 1L] <- path
    stk_paths[level + 1L] <- path
    
    ord <- ord + 1L
    n <- n + 1L
    out[[n]] <- make_row(level, sec, name, recur, status, ord, parent_id, path)
  }
  if (n == 0L) {
    return(data.frame(id=character(), parent_id=character(), period=character(),
                      section=character(), name=character(), recur=logical(),
                      status=character(), level=integer(), order=integer(),
                      path=character(), stringsAsFactors = FALSE))
  }
  df <- do.call(rbind, lapply(out[seq_len(n)], as.data.frame, stringsAsFactors = FALSE))
  rownames(df) <- NULL
  df
}
