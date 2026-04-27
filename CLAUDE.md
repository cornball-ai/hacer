# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Package Overview

`hacer` is a base R package for managing plain-text nested ToDo files with weekly rollover and archiving. Part of the cerebro agent toolchain. Follows tinyverse philosophy (minimal dependencies).

## Development Commands

```bash
# Document, install, and test
r -e 'tinyrox::document(); tinypkgr::install(); tinytest::test_package("hacer")'

# Full check
r -e 'tinypkgr::check()'
```

## Architecture

**Core data flow:**
1. `parse_todo()` - Parse .md (or legacy .txt) file → data.frame with columns: id, parent_id, period, section, name, recur, status, level, order, path
2. `inherit_recur_to_parents()` - Bubble `recur=TRUE` up to parent tasks
3. `rollup_status()` - Update parent status based on children (all x → x, any / → /, etc.)
4. `write_todo_txt()` - Write data.frame back to .md format

**Key modules:**
- `R/parse.R` - Text parsing to data.frame (internal/full schema). `.parse_task_line()` is the dual-format lexer used by `parse_todo`, `roll_day`, `next_day`, and `tasks()`.
- `R/tasks.R` - Agent-facing read API (`tasks()`)
- `R/rollup.R` - Parent status calculation
- `R/advance.R` - Period advancement logic (weekly/monthly/quarterly rollover)
- `R/cli.R` - User-facing functions: `run_monday()`, `fix_parents()`, `sync_from_daily()`, `next_day()`
- `R/roll_day.R` - Day-to-day list rollover (`roll_day()`)
- `R/recurring.R` - Manifest reader + materializer
- `R/migrate.R` - One-shot legacy `.txt` → `.md` converter (`migrate_to_markdown()`)
- `R/io.R` - File I/O (markdown writer, html mirror)
- `R/config.R` - Configuration via `config.yaml` or `hacer_config.R`

## Agent-facing read API

`hacer::tasks()` is the primary read interface for agents. It returns a `data.frame` with columns `id`, `file`, `line`, `depth`, `status`, `recurring`, `text`, `parent_id`, with status normalized to `"todo"`, `"in_progress"`, `"done"`, `"blocked"`.

- IDs are **ephemeral**: `<basename>:L<line>`. Stable across re-parses of an unchanged file, but they shift when lines move. Agents must not persist them across edits.
- Text files in `this_week/` remain the source of truth. `tasks()` is a read-through projection, not a cache.
- Internal callers that need the full schema (sections, period, paths, ordering) should keep using `parse_todo()`.

## Recurring manifest

`recurring.txt` at the repo root declares recurring tasks with frequencies. `run_monday()` reads it (via `read_recurring()`) and materializes day-by-day rows for Daily plus a flat list for Week/Month/Quarter. Non-recurring user tasks carry forward unchanged.

- Frequency syntax: weekday letters `M T W R F` (R = Thursday), `*` alias for `MTWRF`, optional week-of-month prefix `1W:`..`5W:`.
- Nested paths via ` > ` separator; intermediate ancestors auto-materialized.
- Internals in `R/recurring.R`: `.parse_freq()`, `.recurring_for_date()`, `.materialize_daily()`, `.materialize_period()`, `.merge_recurring()`.
- Opt-in: missing `recurring.txt` is a no-op, run_monday behaves as pre-0.1.8.

## Preview mode

Every mutator (`roll_day`, `run_monday`, `fix_parents`, `next_day`, `sync_from_daily`, `instantiate_todo`, `migrate_to_markdown`) accepts `preview = TRUE` and returns a `hacer_preview` describing the would-be change without writing. Set `HACER_PREVIEW=1` to flip the default — useful for one-shot agent invocations that should be inspectable before they touch the user's todo repo. Internals live in `R/preview.R`; each mutator builds a `targets` list of `path -> new_lines` and dispatches via `.write_or_preview()`.

## Task File Format (0.2.0+)

```markdown
# todo_yymmdd_daily.md

## Monday

- [ ] Parent Task
  - [/] Child in progress
  - [x] Child done
- [!] Blocked thing
```

- Standard markdown task list. Two spaces per indent level.
- Status: `[ ]` todo, `[/]` in progress, `[x]` done, `[!]` blocked. `[/]` and `[!]` are non-standard but render fine in Obsidian.
- Day sections in Daily are `## ` (H2). The first line is the H1 file-name header.
- Recurring tasks are declared in `recurring.txt`, not as inline `*` markers.

The dual-format parser still reads pre-0.2.0 files (`[X] - text` syntax in `.txt` files with `# Section` H1 day headers). The writer never emits the legacy format. `migrate_to_markdown()` does a one-shot conversion of the live dir.

- `[!]` is sticky: rollup gives it precedence over all other statuses, and `roll_day()` / `run_monday()` / `next_day()` preserve it verbatim until a human or agent changes it.

## Dependencies

- **Imports:** yaml
- **Suggests:** tinytest
