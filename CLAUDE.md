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
1. `parse_todo()` - Parse .txt file → data.frame with columns: id, parent_id, period, section, name, recur, status, level, order, path
2. `inherit_recur_to_parents()` - Bubble `recur=TRUE` up to parent tasks
3. `rollup_status()` - Update parent status based on children (all x → x, any / → /, etc.)
4. `write_todo_txt()` - Write data.frame back to .txt format

**Key modules:**
- `R/parse.R` - Text parsing to data.frame (internal/full schema)
- `R/tasks.R` - Agent-facing read API (`tasks()`)
- `R/rollup.R` - Parent status calculation
- `R/advance.R` - Period advancement logic (weekly/monthly/quarterly rollover)
- `R/cli.R` - User-facing functions: `run_monday()`, `fix_parents()`, `sync_from_daily()`, `next_day()`
- `R/roll_day.R` - Day-to-day list rollover (`roll_day()`)
- `R/io.R` - File I/O (txt, markdown, html output)
- `R/config.R` - Configuration via `config.yaml` or `hacer_config.R`

## Agent-facing read API

`hacer::tasks()` is the primary read interface for agents. It returns a `data.frame` with columns `id`, `file`, `line`, `depth`, `status`, `recurring`, `text`, `parent_id`, with status normalized to `"todo"`, `"in_progress"`, `"done"`, `"blocked"`.

- IDs are **ephemeral**: `<basename>:L<line>`. Stable across re-parses of an unchanged file, but they shift when lines move. Agents must not persist them across edits.
- Text files in `this_week/` remain the source of truth. `tasks()` is a read-through projection, not a cache.
- Internal callers that need the full schema (sections, period, paths, ordering) should keep using `parse_todo()`.

## Task File Format

```
# Section Header

[ ] - Parent Task
  [/] - Child in progress
  [x] - Child done
[ ] -*Recurring Task
```

- Two spaces per indent level
- Status: `[ ]` todo, `[/]` in progress, `[x]` done
- `*` prefix = recurring (preserved across rollovers)

## Dependencies

- **Imports:** yaml
- **Suggests:** tinytest
