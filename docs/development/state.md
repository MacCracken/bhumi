# bhumi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-06-29 via `cyrius init`. No releases yet.

## Toolchain

- **Cyrius pin**: `6.3.5` (in `cyrius.cyml [package].cyrius`)

## Source

Initial scaffold only.

## Tests

- `tests/bhumi.tcyr` — primary suite (smoke + math; passes on `cyrius test`)
- `tests/bhumi.bcyr` — benchmark stub (no-op)
- `tests/bhumi.fcyr` — fuzz stub

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert

## Consumers

Intended: **aethersafha** (compositor) — instantiates bhumi as its platform
backend (output/input/seat). Not wired yet (M4 / v0.5.0 acceptance gate).

## Next

See [`roadmap.md`](roadmap.md).
