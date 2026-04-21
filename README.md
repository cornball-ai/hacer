# hacer

Plain-text nested ToDo files: parse, roll up, and advance. Part of the [cerebro](https://github.com/cornball-ai/cerebro) agent toolchain.

Edit in any text editor. Run a couple of small helpers. Keep history in git.

## Install

```r
remotes::install_github("cornball-ai/hacer")
```

## TL;DR (first time)

```r
library(hacer)

# point to this repo for the session (or put in ~/.Rprofile to persist)
use_repo("~/To_Do")

# initialize layout + seed files (only once)
instantiate_todo("~/To_Do")   # writes ~/To_Do/this_week and ~/To_Do/archive

# open and edit this week's files in ~/To_Do/this_week
# then, on Mondays:
run_monday()                  # advances week, archives prior
```

## Folder layout

```
~/To_Do/
  ├─ hacer_config.R           # edit paths/options here
  ├─ this_week/               # live files you edit daily
  │   ├─ ToDo_YYMMDD_Daily.txt
  │   ├─ ToDo_YYMMDD_Week.txt
  │   ├─ ToDo_YYMMDD_Month.txt
  │   └─ ToDo_YYMMDD_Quarter.txt
  └─ archive/                 # prior weeks (commit/push to GitHub)
```

## Editing rules (syntax)

- Two spaces per indent level for sub-tasks.
- Status: `[ ]` = todo, `[/]` = in progress, `[x]` = done.
- Recurring: prefix name with `*` (e.g., `[ ] -*Exercise`) → `recur = TRUE`.
- Parents auto-roll:
  - all children `x` → parent `x`
  - any `/` or mix of `x`/`/`/blank → parent `/`
  - all blank → parent blank

## Period & carry-over logic

- Weekly rollover (`run_monday()`):
  - **Daily/Week**: drop items that are `x` and **not** recurring; keep `/`; keep all `*`.
  - **Month/Quarter**: keep `x` until period changes; at new month/quarter, non-recurring `x` are cleared; recurring `x` reset to blank.
  - Recurring `*` **bubble up to parents** so containers (projects) stick around.
- **Strict subset**: Week ⊆ Month ⊆ Quarter. If you add an ad-hoc task in **Daily**, you can sync it upward.

## Common commands

```r
# set the active repo for the session
hacer::use_repo("~/To_Do")

# weekly rollover (creates new ToDo_YYMMDD_* in this_week/, archives prior)
hacer::run_monday()

# advance to tomorrow's daily section (preserves blank-line groups)
hacer::next_day()

# promote ad-hoc Daily additions up into Week/Month/Quarter
hacer::sync_from_daily()

# fix parent statuses in a file you're editing (rolls parents to / or x)
hacer::fix_parents(file_name = "~/To_Do/this_week/ToDo_250915_Daily.txt")
```

> Tip: add `use_repo("~/To_Do")` to `~/.Rprofile` so you don't need to call it each session.

## Weekly routine (Mon AM)

1. Open `~/To_Do/this_week/ToDo_YYMMDD_Daily.txt` and plan the week/day.
2. `run_monday()` to advance periods and archive last week.
3. `git -C ~/To_Do add archive && git -C ~/To_Do commit -m "Archive week" && git -C ~/To_Do push`.

## Day-to-day

- Edit the **Daily** file directly.
- If you add a new task tree in Daily and want it reflected up: `sync_from_daily()`.
- If a child is `/` and you want the parent to reflect it: `fix_parents("<that file>")`.

## Cron (optional, Ubuntu)

Run rollover every Monday at 06:00:

```bash
crontab -e
# add:
0 6 * * MON Rscript -e 'hacer::use_repo("~/To_Do"); hacer::run_monday()'
```

## Git tips

Add live artifacts to `.gitignore` (archive is what you push):

```
this_week/
*.html
*.md
```

## Troubleshooting

- **Function not found**: reinstall package or ensure it's exported in `NAMESPACE`; `library(hacer)`.
- **Wrong repo**: call `use_repo("~/To_Do")` again (session-scoped).
- **No new files**: check `hacer_config.R` paths; verify `this_week/` exists.
- **Parent status didn't change**: run `fix_parents("<file>")`.

## License

Apache 2.0
