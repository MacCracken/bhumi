# 001 — `cyrius test` links [lib].modules: functions are global, constants are not

A test (`.tcyr`) or any consumer that wants to **name a constant** defined in
a bhumi domain module (`src/output.cyr`, ...) by identifier must
**source-include** the module — in-tree via `include "src/main.cyr"`, or
externally via the flat `dist/bhumi.cyr` bundle. Functions need no include;
constants do.

## Why (the non-obvious part)

`cyrius test` auto-injects the `[lib].modules` listed in `cyrius.cyml` and
**links** them into the test binary. Linking exposes each module's **functions**
as global symbols — so `bhumi_xrgb(...)`, `bhumi_fb_new(...)`, and the rest
resolve in a `.tcyr` with *no* `include` at all. But a module's top-level
`enum` and `var` **constants are not exported by the link step** — they are only
visible to a compilation unit that has the module's *source* in scope.

The scaffold test (`tests/bhumi.tcyr`) originally used only stdlib functions
(`assert`, `test_group`, ...), all auto-included via `cyrius.cyml [deps.stdlib]`,
and never named a module constant — so it carried no `include` line and passed.
The first time it referenced `BHUMI_FMT_XRGB8888` (an `enum` member in
`output.cyr`), the compiler reported it `undefined` even though the sibling
`bhumi_fb_*` **functions** from the same file resolved fine. The fix was not in
`output.cyr` — it was the missing `include "src/main.cyr"` at the top of the
test. (Sibling `darshana`'s test works for exactly this reason: it
source-includes `src/main.cyr` and so can name its `TIO_*` constants.)

## What this is NOT

Not "enums don't cross include boundaries." A `var`/`enum` constant crosses a
nested source-include fine (test → `src/main.cyr` → `src/output.cyr`) — verified.
The distinction is **link vs. source**: the link path (`cyrius test`'s
`[lib].modules` auto-injection) carries functions but not constants; a source
include carries both.

## Consequences

- Every `.tcyr` that names a bhumi constant begins with `include "src/main.cyr"`.
- External consumers `include "dist/bhumi.cyr"` (the flat bundle is all source),
  so they see functions and constants both — this invariant does not bite them.
- Choosing `enum` vs top-level `var` for a public constant is a style call, not a
  visibility one: neither is reachable across the link path without a source
  include, and both are reachable with one.
