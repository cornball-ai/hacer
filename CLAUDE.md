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
- `R/parse.R` - Text parsing to data.frame
- `R/rollup.R` - Parent status calculation
- `R/advance.R` - Period advancement logic (weekly/monthly/quarterly rollover)
- `R/cli.R` - User-facing functions: `run_monday()`, `fix_parents()`, `sync_from_daily()`, `next_day()`
- `R/io.R` - File I/O (txt, markdown, html output)
- `R/config.R` - Configuration via `config.yaml` or `hacer_config.R`

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
