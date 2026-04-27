# R/io.R
build_todo_txt_lines <- function(df, file, period, cfg = todo_config()) {
  lines <- character()
  lines <- c(lines, paste0("# ", basename(file)))

  if (period == "Daily") {
    secs <- unique(df$section)
    secs <- secs[!is.na(secs)]
    for (s in secs) {
      lines <- c(lines, "", "#######################################", paste0("\n# ", s), "")
      part <- df[df$section == s, , drop=FALSE]
      lines <- c(lines, .df_to_lines(part, cfg$indent))
    }
  } else {
    lines <- c(lines, "", "#######################################", "")
    lines <- c(lines, .df_to_lines(df, cfg$indent))
  }
  lines
}

write_todo_txt <- function(df, file, period, cfg = todo_config()) {
  writeLines(build_todo_txt_lines(df, file, period, cfg), file)
}

.df_to_lines <- function(df, indent) {
  if (!nrow(df)) return(character())
  df <- df[order(df$order), , drop=FALSE]
  out <- character(nrow(df))
  for (i in seq_len(nrow(df))) {
    pad <- paste(rep(" ", df$level[i] * indent), collapse = "")
    stat <- paste0("[", df$status[i], "]")
    if (isTRUE(df$recur[i])) {
      out[i] <- paste0(pad, stat, " -*", df$name[i])
    } else {
      out[i] <- paste0(pad, stat, " - ", df$name[i])
    }
  }
  out
}

# optional mirrors:
build_markdown_lines <- function(df, file_md, period, cfg = todo_config()) {
  lines <- character()
  lines <- c(lines, paste0("# ", sub("\\.md$", "", basename(file_md))))

  one <- function(df) {
    if (!nrow(df)) return(character())
    df <- df[order(df$order), , drop=FALSE]
    out <- character(nrow(df))
    for (i in seq_len(nrow(df))) {
      pad <- paste(rep("  ", df$level[i]), collapse = "")
      ck  <- if (df$status[i] == "x") "x" else if (df$status[i] == "/") "-" else " "
      nm  <- if (df$recur[i]) paste0("*", df$name[i]) else df$name[i]
      out[i] <- paste0(pad, "- [", ck, "] ", nm)
    }
    out
  }

  if (period == "Daily") {
    secs <- unique(df$section); secs <- secs[!is.na(secs)]
    for (s in secs) {
      lines <- c(lines, "", paste0("## ", s), "")
      lines <- c(lines, one(df[df$section == s, , drop=FALSE]))
    }
  } else {
    lines <- c(lines, "", "## Tasks", "")
    lines <- c(lines, one(df))
  }
  lines
}

write_markdown <- function(df, file_md, period, cfg = todo_config()) {
  writeLines(build_markdown_lines(df, file_md, period, cfg), file_md)
}

build_simple_html_lines <- function(df, file_html, period) {
  esc <- function(x) { x <- gsub("&","&amp;",x, fixed=TRUE); x <- gsub("<","&lt;",x,fixed=TRUE); gsub(">","&gt;",x,fixed=TRUE) }
  lines <- c("<!doctype html>","<meta charset='utf-8'>",
             "<style>body{font-family:sans-serif;max-width:800px;margin:2rem auto} .lvl0{margin-left:0} .lvl1{margin-left:1.5rem} .lvl2{margin-left:3rem} .done{opacity:.7;text-decoration:line-through} .prog{font-weight:bold}</style>",
             paste0("<h1>", esc(period), "</h1>"))

  to_ul <- function(df) {
    if (!nrow(df)) return(character())
    df <- df[order(df$order), , drop=FALSE]
    out <- character(nrow(df))
    for (i in seq_len(nrow(df))) {
      cls <- paste0("lvl", df$level[i], " ",
                    if (df$status[i]=="x") "done" else if (df$status[i]=="/") "prog" else "")
      nm <- if (df$recur[i]) paste0("&#9733; ", esc(df$name[i])) else esc(df$name[i])
      box <- if (df$status[i]=="x") "&#x2611;" else if (df$status[i]=="/") "&#x25B6;" else "&#x2610;"
      out[i] <- paste0("<div class='", cls, "'>", box, " ", nm, "</div>")
    }
    out
  }

  if (period == "Daily") {
    secs <- unique(df$section); secs <- secs[!is.na(secs)]
    for (s in secs) {
      lines <- c(lines, paste0("<h2>", esc(s), "</h2>"))
      lines <- c(lines, to_ul(df[df$section == s, , drop=FALSE]))
    }
  } else {
    lines <- c(lines, to_ul(df))
  }
  lines
}

write_simple_html <- function(df, file_html, period) {
  writeLines(build_simple_html_lines(df, file_html, period), file_html)
}
