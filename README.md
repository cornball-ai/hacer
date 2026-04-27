# hacer

Plain-text nested ToDo files: parse, roll up, and advance.

Edit in any text editor. Run a couple of small helpers. Keep history in git.

## Install

```r
remotes::install_github("cornball-ai/hacer")
```

## TL;DR (first time)

```r
library(hacer)

# point to this repo for the session (or put in ~/.Rprofile to persist)
use_repo("~/todo")

# initialize layout + seed files (only once)
instantiate_todo("~/todo")   # writes ~/todo/this_week and ~/todo/archive

# open and edit this week's files in ~/todo/this_week
# then, on Mondays:
run_monday()                  # advances week, archives prior
```

## Folder layout

```
~/todo/
  ├─ hacer_config.R           # edit paths/options here
  ├─ this_week/               # live files you edit daily
  │   ├─ todo_yymmdd_daily.txt
  │   ├─ todo_yymmdd_week.txt
  │   ├─ todo_yymmdd_month.txt
  │   └─ todo_yymmdd_quarter.txt
  └─ archive/                 # prior weeks (commit/push to GitHub)
```

> Pre-0.1.7 repos used capitalized `ToDo_YYMMDD_*.txt` filenames. Readers stay case-insensitive so legacy files keep working — new writes always emit the lowercase form.

## Editing rules (syntax)

- Two spaces per indent level for sub-tasks.
- Status: `[ ]` = todo, `[/]` = in progress, `[x]` = done, `[!]` = blocked (attention needed).
- Recurring: prefix name with `*` (e.g., `[ ] -*Exercise`) → `recur = TRUE`.
- Parents auto-roll:
  - any child `[!]` → parent `[!]` (blocked bubbles up; takes precedence)
  - all children `x` → parent `x`
  - any `/` or mix of `x`/`/`/blank → parent `/`
  - all blank → parent blank
- Blocked is sticky. `roll_day()`, `run_monday()`, and `next_day()` all preserve `[!]` items verbatim until you explicitly change them.

## Period & carry-over logic

- Weekly rollover (`run_monday()`):
  - **Daily/Week**: drop items that are `x` and **not** recurring; keep `/`; keep all `*`.
  - **Month/Quarter**: keep `x` until period changes; at new month/quarter, non-recurring `x` are cleared; recurring `x` reset to blank.
  - Recurring `*` **bubble up to parents** so containers (projects) stick around.
- **Strict subset**: Week ⊆ Month ⊆ Quarter. If you add an ad-hoc task in **Daily**, you can sync it upward.

## Common commands

```r
# set the active repo for the session
hacer::use_repo("~/todo")

# weekly rollover (creates new todo_yymmdd_* in this_week/, archives prior)
hacer::run_monday()

# advance to tomorrow's daily section (preserves blank-line groups)
hacer::next_day()

# promote ad-hoc Daily additions up into Week/Month/Quarter
hacer::sync_from_daily()

# fix parent statuses in a file you're editing (rolls parents to / or x)
hacer::fix_parents(file_name = "~/todo/this_week/todo_250915_daily.txt")

# day-to-day: copy yesterday forward, drop done non-recurring, log to done.log
hacer::roll_day()

# read everything as a data.frame (parsed from this_week/)
hacer::tasks()
```

> Tip: add `use_repo("~/todo")` to `~/.Rprofile` so you don't need to call it each session.

## For LLM CLI agents

hacer's functions work fine as one-shot R calls from any agent that can spawn `Rscript` or `r` (Claude Code, Codex, etc.). Point hacer at a repo with the `HACER_REPO` environment variable — no `use_repo()` required:

```bash
HACER_REPO=~/todo r -e 'hacer::run_monday()'
HACER_REPO=~/todo r -e 'hacer::next_day()'
HACER_REPO=~/todo r -e 'hacer::fix_parents("~/todo/this_week/todo_250915_daily.txt")'
```

Resolution order for the repo path is: `repo_dir` argument → `options("hacer.repo")` → `HACER_REPO` env var → `tools::R_user_dir("hacer", "data")`. The env var makes the "stateless one-shot" case ergonomic. The `R_user_dir()` fallback is CRAN-safe but ugly (`~/.local/share/R/hacer/` on Linux), so most users `instantiate_todo("~/todo")` and persist `use_repo("~/todo")` in `~/.Rprofile`.

If you're running [corteza](https://github.com/cornball-ai/corteza)'s MCP server, hacer's exports register automatically as `hacer::*` tools (on the corteza `hacer` branch) so any MCP-capable agent can call them.

### Look before you leap: preview mode

Every function that writes to disk takes `preview = TRUE` and returns a `hacer_preview` object describing what would change without touching the filesystem:

```r
pv <- hacer::roll_day(preview = TRUE)
print(pv)
#> hacer preview
#>   created (1):
#>     + ~/todo/this_week/todo_250916_daily.txt
#>   done.log appends (2):
#>     > 2025-09-16  [x] - Some finished task
#>     > 2025-09-16    [x] - A nested done item
```

Set `HACER_PREVIEW=1` to flip the default for a one-shot CLI agent so it never accidentally writes:

```bash
HACER_REPO=~/todo HACER_PREVIEW=1 r -e 'hacer::run_monday()'
HACER_REPO=~/todo HACER_PREVIEW=1 r -e 'hacer::roll_day()'
```

Covers `roll_day()`, `run_monday()`, `fix_parents()`, `next_day()`, `sync_from_daily()`, and `instantiate_todo()`. The preview lists `files_created`, `files_modified`, line-level diffs, and any `done.log` lines that would be appended.

### Reading: `tasks()` is the structured API

`hacer::tasks()` is the read interface for agents. It returns the entire task set across `this_week/` as a `data.frame` so you can filter and reason without re-parsing text:

```r
tasks()                          # everything across all four cadences
tasks(status = "in_progress")    # just [/] tasks
tasks(recurring = TRUE)          # just *-prefixed tasks
tasks(file = "~/todo/this_week/todo_250915_daily.txt")
```

Columns: `id`, `file`, `line`, `depth`, `status`, `recurring`, `text`, `parent_id`. `status` normalizes the bracket symbols to `"todo"`, `"in_progress"`, `"done"`, and `"blocked"`.

IDs are **ephemeral** (`<basename>:L<line>`). They're stable across re-parses of an unchanged file but shift the moment a line is inserted or removed. Don't persist them across edits — re-call `tasks()` and rebuild your view.

The plain-text files remain the source of truth. `tasks()` is a read-through projection, not a cache.

## Agent consumption (Cornelius)

hacer's plain-text files are designed to be read by other agents. [Cornelius](https://github.com/cornball-ai/cornelius) (a personal briefing bot) parses your todo files every morning, matches project tokens against `saber::projects()` and a local alias list, pulls recent git commits for matched repos, and synthesizes a briefing via `llm.api`. The briefings land in Matrix/Element DM.

Cornelius reads four cadences: **Daily** (today/yesterday), **Week**, **Month**, and **Quarter**. On Mondays it shifts to weekly review; Sundays it sends a week-ahead preview of Monday's section. First Monday of a month/quarter adds the Month/Quarter files to the briefing.

To get your repos tracked: add them to your todo files (any cadence) and ensure the token resolves — either the repo basename matches, or add an alias in `cornelius/aliases.txt`.

## Weekly routine (Mon AM)

1. Open `~/todo/this_week/todo_yymmdd_daily.txt` and plan the week/day.
2. `run_monday()` to advance periods and archive last week.
3. `git -C ~/todo add archive && git -C ~/todo commit -m "Archive week" && git -C ~/todo push`.

## Day-to-day

- Edit the **Daily** file directly.
- If you add a new task tree in Daily and want it reflected up: `sync_from_daily()`.
- If a child is `/` and you want the parent to reflect it: `fix_parents("<that file>")`.

## Cron (optional, Ubuntu)

Run rollover every Monday at 06:00:

```bash
crontab -e
# add:
0 6 * * MON Rscript -e 'hacer::use_repo("~/todo"); hacer::run_monday()'
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
- **Wrong repo**: call `use_repo("~/todo")` again (session-scoped).
- **No new files**: check `hacer_config.R` paths; verify `this_week/` exists.
- **Parent status didn't change**: run `fix_parents("<file>")`.

## License

Apache 2.0
