# hacer Implementation Plan

A plan for Claude Code to execute in the `cornball-ai/hacer` repo. Start by reading `README.md`, `CLAUDE.md`, `DESCRIPTION`, and everything in `R/` and `inst/tinytest/` to understand current parser and rollover semantics before changing any file.

## Context

hacer is a plain-text nested todo system in R. Current shape:

- Files live in `<repo>/this_week/` and archive in `<repo>/archive/`.
- Syntax: `[ ]` todo, `[/]` in progress, `[x]` done; `*` prefix for recurring; `-` prefix on task name; two-space indent for nesting.
- Four cadence files per week: Daily, Week, Month, Quarter (`ToDo_YYMMDD_<Cadence>.txt`).
- Existing mutators: `instantiate_todo()`, `run_monday()`, `next_day()`, `sync_from_daily()`, `fix_parents()`.
- Repo path resolution: `repo_dir` arg → `options("hacer.repo")` → `HACER_REPO` env var → `getwd()`.

## Design principles

- Plain text is the source of truth. No sidecar JSON, no database.
- Ordering encodes priority. Top = highest. No priority field.
- Tree shape encodes project. No tags.
- One source of truth per fact. If it's in the text, don't duplicate it in metadata.
- One-list mode and four-cadence mode are the same machinery with different file counts. Behavior is driven by which files exist, not by a mode flag.
- Base R only. No new package dependencies beyond what's in `DESCRIPTION` today.
- Tests with tinytest in `inst/tinytest/`.
- Apache 2.0 stays.

## Explicitly out of scope

Do not add any of these, even if they seem reasonable while working on adjacent code:

- Tags or contexts (`@foo`, `+proj`)
- Visible persistent per-task IDs written into the text
- Priority letters, numbers, or any explicit priority field
- Per-task due dates or scheduled dates
- Effort estimates
- Per-task inline work logs
- External link fields
- Sidecar JSON or any non-text data file (the one exception is `done.log` in Task 1, which is append-only text)
- MCP-layer changes (corteza re-exports hacer's exports automatically)

If any of these becomes needed later, it gets added then with a concrete use case. Not pre-emptively.

## Tasks

Execute in order. Each task ends with tests green and a commit before the next begins. If task N uncovers a needed refactor in code touched by task N-1, prefer a separate commit so history stays bisectable.

---

### Task 1: `roll_day()` — automate the rolling list

**Goal.** Replace the manual "copy yesterday's list to today, strip finished items" workflow with a single call.

**Behavior.**

- Find the most recent existing file of each cadence present in `this_week/`.
- Create today's files (`ToDo_<today>_<Cadence>.txt`) by copying the prior file forward.
- In the new files:
  - Keep `[ ]`, `[/]`, `[!]` items as-is.
  - Keep recurring items (`*` prefix): non-done recurring unchanged, recurring `[x]` resets to `[ ]`.
  - Drop non-recurring `[x]` items.
- For every dropped item, append a line to `<repo>/done.log` in this format:
  ```
  YYYY-MM-DD  <indent><task text>
  ```
- Preserve line ordering exactly. Preserve blank-line groupings.
- Do not archive yet — `run_monday()` handles week-boundary archival. `roll_day()` is day-to-day only.

**Mode handling.** If only Daily exists in `this_week/`, only Daily is rolled. If all four cadences exist, all four are rolled. No mode flag; file presence drives behavior.

**Relationship to `next_day()`.** Inspect the current implementation. If `next_day()` already does something close to this, consolidate: either rename it to `roll_day()` with a deprecation shim, or keep `next_day()` for its specific semantic (advancing within a single file's day-sections) and add `roll_day()` as the file-level roll. Document which was chosen and why in the commit message.

**Files.** New or renamed `R/roll_day.R`. Update `NAMESPACE` via the package's existing export mechanism.

**Acceptance.**

- One-list mode: with only `ToDo_<yesterday>_Daily.txt` present, `roll_day()` creates `ToDo_<today>_Daily.txt` with the correct content.
- Four-cadence mode: all four files are rolled in one call.
- Recurring `[x]` resets to `[ ]` in the new file.
- Non-recurring `[x]` items do not appear in the new file and do appear in `done.log`.
- `[/]` and `[!]` items carry forward unchanged.
- Parent/child indentation preserved.
- Empty input (no prior-day files) is a no-op with a clear message, not an error.
- `done.log` is created if missing and appended to if present.

---

### Task 2: `hacer::tasks()` — structured read API

**Goal.** One function that returns the entire task set as a `data.frame`, so agents (and ad-hoc R sessions) can filter and reason without re-parsing text.

**Signature.**

```r
hacer::tasks(file = NULL, status = NULL, recurring = NULL, blocked = NULL)
```

- `file = NULL`: parse all files in `this_week/`.
- `file = <path>`: parse one file.
- `status`, `recurring`, `blocked`: optional filters applied to the result.

**Columns.**

| Column      | Type      | Notes                                                            |
|-------------|-----------|------------------------------------------------------------------|
| `id`        | character | ephemeral, hash of file basename + line number                   |
| `file`      | character | basename, not full path                                          |
| `line`      | integer   | 1-indexed line number in source file                             |
| `depth`     | integer   | 0 = root, +1 per indent level                                    |
| `status`    | character | `"todo"`, `"in_progress"`, `"done"`, `"blocked"`, or `"blank"`   |
| `recurring` | logical   | `TRUE` if task has the `*` prefix                                |
| `text`      | character | task text with status brackets and `-`/`*` prefixes stripped     |
| `parent_id` | character | `id` of nearest ancestor with lower depth; `NA` for root tasks   |

**Ephemerality.** IDs are deterministic for a given parse but do not persist across edits. Document this in the `.Rd` file so agents don't rely on them cross-session.

**No tidyverse.** Build the `data.frame` with base R. Do not introduce `dplyr`, `tibble`, `data.table`, or similar.

**Files.** New `R/tasks.R`. May extract shared lexer code into `R/parse.R` if `fix_parents()` and `tasks()` can share it cleanly.

**Acceptance.**

- Data-frame shape matches the column spec exactly.
- `parent_id` resolves correctly across ≥3 levels of nesting.
- Filter args produce correct subsets.
- Parsing the same file twice produces the same IDs.
- Round-trip test: fixtures in `inst/tinytest/` cover all four statuses, recurring and non-recurring, and nested trees.

---

### Task 3: `[!]` blocked status

**Goal.** Fourth status marker for tasks that cannot currently advance.

**Lexer.** Accept `[!]` alongside `[ ]`, `[/]`, `[x]`. Normalize to `status = "blocked"` in `tasks()`.

**Parent rollup.** Extend `fix_parents()` rules:

- If any child is `[!]` → parent is `[!]`. (Blocked bubbles up as "attention needed.")
- Else if any child is `[/]`, or children are a mix of `[x]` and blank/`[ ]` → parent is `[/]`.
- Else if all children are `[x]` → parent is `[x]`.
- Else parent is blank.

Blocked takes precedence over the existing rules. Recurring `*` remains orthogonal: it affects rollover behavior, not rollup.

**Rollover behavior.** Both `roll_day()` (Task 1) and `run_monday()` preserve `[!]` unchanged — not dropped, not cleared, not reset. A blocked task stays blocked until a human or agent explicitly changes it.

**Files.** Update the lexer wherever status is read, `R/fix_parents.R`, `R/roll_day.R`, `R/run_monday.R`.

**Acceptance.**

- `[!]` parses to `status = "blocked"` in `tasks()`.
- `fix_parents()` correctly propagates `[!]` upward, including across multiple indent levels.
- `roll_day()` preserves `[!]` items verbatim.
- `run_monday()` preserves `[!]` items verbatim.
- Mixed-status fixtures (blocked + recurring, blocked + done siblings, etc.) produce the documented parent status.

---

### Task 4: Preview mode for mutators

**Goal.** Every function that writes to disk accepts `preview = FALSE`. When `preview = TRUE`, the function returns a description of what would change and touches nothing on disk.

**Scope.** `roll_day()`, `run_monday()`, `next_day()` (if retained), `sync_from_daily()`, `fix_parents()`, `instantiate_todo()`.

**Return value in preview mode.** A `list` of class `"hacer_preview"`:

```r
list(
  files_created    = character(),
  files_modified   = character(),
  lines_added      = data.frame(file = , line = , text = , stringsAsFactors = FALSE),
  lines_removed    = data.frame(file = , line = , text = , stringsAsFactors = FALSE),
  done_log_appends = character()   # lines that would be appended to done.log
)
```

Give it a minimal `print.hacer_preview()` method so an agent (or human) calling from an R prompt gets a readable summary, not a raw list dump.

**Env var.** `HACER_PREVIEW=1` flips the default of `preview` to `TRUE` for all mutators. Intended for safe exploration from the CLI:

```sh
HACER_REPO=~/To_Do HACER_PREVIEW=1 r -e 'hacer::run_monday()'
```

**Acceptance.**

- Preview mode produces zero filesystem changes (verify via a file mtime check on a fixture directory).
- The `hacer_preview` object, if applied to the filesystem, produces the same end state as the non-preview call would. Test this by comparing an actual run to a preview + simulated apply.
- `HACER_PREVIEW=1` env var flips defaults correctly.
- `print.hacer_preview` renders a sensible summary.
- Preview mode is documented in the README with a one-shot CLI example.

---

## Non-task hygiene

- Update `README.md`: document `roll_day()`, `tasks()`, `[!]` status, preview mode, and one-list mode as a first-class use case.
- Update `CLAUDE.md`: note that `hacer::tasks()` is the primary read interface for agents, IDs are ephemeral, and text files remain the source of truth.
- No new entries in `DESCRIPTION`'s `Imports` or `Suggests`.
- Keep `R CMD check` clean.

## Validation before declaring done

- `R CMD check` passes with no new `NOTE`, `WARNING`, or `ERROR` beyond what's already present on `main`.
- All tinytest suites pass, including the new fixtures.
- Round-trip smoke test: from an empty `tempdir()`, `instantiate_todo()` → hand-edit a fixture → `tasks()` → `roll_day()` → `tasks()` again → observed diff matches `roll_day(preview = TRUE)`.
- README example sequences run end-to-end without editing state outside the test directory.

## What "done" looks like in one sentence

A human can still edit text files in `this_week/` exactly as before, with `[!]` as a new status available; an agent calls `hacer::tasks()` to get a data.frame, `roll_day()` to advance the day, and sets `HACER_PREVIEW=1` when it wants to look before leaping.