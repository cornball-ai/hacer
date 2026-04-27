% tinyrox says don't edit this manually, but it can't stop you!
\name{migrate_to_markdown}
\alias{migrate_to_markdown}
\title{Migrate legacy .txt todo files to markdown .md}
\usage{
migrate_to_markdown(cfg = todo_config(), preview = .preview_default())
}
\arguments{
\item{cfg}{Config from [todo_config()].}

\item{preview}{If `TRUE`, return a `hacer_preview` without writing.
Defaults to the `HACER_PREVIEW=1` env var or `FALSE`.}
}
\description{
Walks `cfg$live_dir` for `.txt` files matching the `todo_*` pattern,
reads each via the dual-format parser, writes a `.md` companion in the
new markdown task-list syntax (`- [X] text`), and removes the `.txt`
source after a successful write.
Surfaces a warning listing any tasks that carried the legacy `*`
recurring marker — the new writer drops `*` entirely, so add those
paths to `recurring.txt` if you want them to keep recurring.
Archive files are not touched. If you want them migrated, do it
manually with `git mv` + a script — or wait until the question matters
enough to dial the defaults in.
}
