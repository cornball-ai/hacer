# hacer 0.2.2.4

- `survey()` treats a top-level todo item as the project and the items
  under it as its tasks: the parent is no longer a row of its own unless
  it has no open children or carries `[!]` / `#blocked`, and `detail` is
  the task's path below the project.

# hacer 0.2.2.3

- `survey()` reads note contents: one row per open task-list item in any
  `.md` under the tasks dir, ranked like todo items (`[!]` and `#blocked`
  1, `[/]` 2, an open item 2 in a note changed within the window and 3
  in an older one). Fenced code blocks are skipped. Git `commits` rows
  list up to three recent subjects.
- New `survey_report()` renders a survey as markdown, one section per
  project, most urgent first, matching project names across sources
  ignoring case, spaces and punctuation.

# hacer 0.2.2.2

- `[!]` now means important, not blocked. `rollup_status()` no longer bubbles
  it up: an important child counts as open for its parent, and an important
  parent keeps its marker until every child is done. `run_monday()` and
  `next_day()` still carry `[!]` forward unchanged.
- Blocked items are tagged with `#blocked` in the item text. `tasks()` gains
  a logical `blocked` column, and its `status` now normalizes `[!]` to
  `"important"`. The `blocked` filter argument selects tagged rows.
- New single-file workflow: `todo_file()` names the hand-edited
  `this_week/todo.md`, `snapshot()` copies it to `todo_yymmdd.md` each day,
  and `archive_old()` sweeps dated files from before this week into the
  archive, optionally committing them in the archive's git repo. `tasks()`
  reads `todo.md` alongside the period files.
- New `survey()` (#16) ranks ongoing work into one data.frame: todo items,
  dirty or unpushed git repos under `~`, open GitHub PRs via `gh`, and
  recently changed notes. Owners and the notes directory come from
  `options(hacer.survey_owners, hacer.tasks_dir)` or the
  `HACER_SURVEY_OWNERS` / `HACER_TASKS_DIR` environment variables.
- `hacer_preview` gains a `files_moved` table, shown by `print()`.
- `inst/systemd/` ships a user timer and service for the nightly snapshot;
  the repo path comes from a drop-in so the unit stays generic.
- CI runs on pull requests only, uses the rapt backend and fails on check
  warnings (#17).
- `mirror_subtree()` syncs a todo subtree across files (#15).

# hacer 0.2.2.1

- `catch_up()` rolls a repo forward through missed Mondays; `next_day()`
  handles markdown headings; `roll_day()` removed (#13, #14).

# hacer 0.2.2

- Blank-line spacing between top-level groups; CI fix (#12).

# hacer 0.2.1

- Recurring materialization order is depth-first preorder (#11).

# hacer 0.2.0

- Markdown task-list syntax in `.md` files, with `migrate_to_markdown()` for
  one-shot conversion of legacy `.txt` repos (#10).

# hacer 0.1.8

- Recurring-task manifest `recurring.txt` (#9).

# hacer 0.1.7

- Single-space writer and lowercase filenames (#8).

# hacer 0.1.6

- Preview mode for every mutator and the `HACER_PREVIEW` env var (#7).

# hacer 0.1.5

- `[!]` blocked status in the lexer, rollup and rollover (#6).

# hacer 0.1.4

- `tasks()` data.frame API for structured reads (#5).

# hacer 0.1.3

- `roll_day()` for day-to-day rollover (#4).

# hacer 0.1.2

- Default `repo_dir` is `tools::R_user_dir("hacer", "data")` (#3).

# hacer 0.1.1

- `HACER_REPO` env var for one-shot CLI agents (#2).

# hacer 0.1.0

- Renamed from todoengine to hacer and retrofitted for cerebro (#1).
