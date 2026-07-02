# bhumi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.1.0** — scaffolded 2026-06-29 via `cyrius init`. No releases yet.

## Toolchain

- **Cyrius pin**: `6.3.5` (in `cyrius.cyml [package].cyrius`)

## Source

- `src/main.cyr` — lib header + convenience entry (includes domain modules;
  still carries the `bhumi_scaffold_ok` sentinel until M4).
- `src/output.cyr` — **M1 in progress.** Pixel-production half: a software
  `BhumiFb` framebuffer (XRGB8888) with construction, bounds-checked pixel
  set/get, and clear. Kernel scanout seam (agnodrm → `blit#39`) not yet wired —
  that ABI isn't in this checkout (agnos snapshot tops at 1.45.16 /
  `winsize#60`; `#39` is an unassigned gap).

## Tests

- `tests/bhumi.tcyr` — primary suite: smoke + `output.cyr` framebuffer model
  (29 assertions, passes on `cyrius test`). Source-includes `src/main.cyr` (see
  [architecture 001](../architecture/001-cyrius-test-const-visibility.md)).
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
