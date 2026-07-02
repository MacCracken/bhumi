# bhumi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**0.2.0** — M1 (output) shipped 2026-07-02. Scaffolded 2026-06-29 via
`cyrius init` (0.1.0).

## Toolchain

- **Cyrius pin**: `6.3.34` (in `cyrius.cyml [package].cyrius`; matches the active
  toolchain). Bumped from 6.3.5 so `lib/` carries the agnos 1.51.0 syscall
  surface — the `fbinfo`#38 / `blit`#39 scanout wrappers M1 needs.

## Source

- `src/main.cyr` — lib header + convenience entry (includes domain modules;
  still carries the `bhumi_scaffold_ok` sentinel until M4).
- `src/output.cyr` — **M1.** Pixel-production half: a software `BhumiFb`
  framebuffer (XRGB8888) with construction, bounds-checked pixel set/get, clear.
- `src/scanout.cyr` — **M1.** Kernel handoff: scans a `BhumiFb` to the display
  via agnos `fbinfo`#38 / `blit`#39 (`bhumi_output_present` / `_query` /
  `_format_ok` + `bhumi_fbinfo_*`). Kernel calls are behind
  `#ifdef CYRIUS_TARGET_AGNOS`; the host build stubs them (-1) and stays
  testable. Cross-target verified: the `--agnos` binary emits `syscall`
  `eax=38`/`39`. See [ADR 0001](../adr/0001-scanout-via-agnos-fbinfo-blit.md).
- `src/pattern.cyr` — **M1.** Bring-up test patterns over a `BhumiFb`:
  SMPTE-style color bars and a grayscale XOR gradient — the "known test pattern"
  of the M1 acceptance gate.
- `programs/scanout-demo.cyr` — **M1 acceptance artifact.** Queries geometry
  (720p fallback off-agnos), draws bars, presents. Runs on real/QEMU agnos.
- `src/input.cyr` — **M2 in progress.** Events-in: a normalized key-event model
  over **USB HID usage codes** (page 0x07) + `bhumi_kbd_diff`, which diffs 8-byte
  HID boot keyboard reports into press/release events (release derived from
  report state). Keyboards attach over USB/xHCI HID — agnos has no PS/2.
- `src/kbscan.cyr` — **M2 in progress.** Kernel drain: `bhumi_input_poll` pulls
  HID reports via agnos `kbscan`#42 and diffs them into events (`sys_kbscan`
  behind `#ifdef CYRIUS_TARGET_AGNOS`; host stub → 0). Cross-target verified: the
  `--agnos` binary emits `syscall` `eax=42`. **Pointer input is deferred** — no
  pointer syscall exists (surface tops at 1.51.0), so v0.3.0 is keyboard-only.

**M1 is shipped as v0.2.0** — code-complete against the real ABI and verified
cross-target (host: 86 assertions + fuzz; agnos: emits `syscall` #38/#39). The
end-to-end *visual* acceptance (bars on a real/QEMU agnos framebuffer, via
`scanout-demo`) is a manual downstream step, not reachable from host CI.

## Tests

- `tests/bhumi.tcyr` — primary suite: smoke + `output.cyr` / `pattern.cyr` /
  `scanout.cyr` + edge cases (86 assertions, passes on `cyrius test`).
  Source-includes `src/main.cyr` (see
  [architecture 001](../architecture/001-cyrius-test-const-visibility.md)).
- `fuzz/bhumi.fcyr` — property fuzz over the public output surface
  (`cyrius fuzz`); holds to 200k+ iterations.
- `tests/bhumi.bcyr` — benchmarks: 720p color-bars / XOR full-frame paint
  throughput (`cyrius bench tests/bhumi.bcyr`).
- CI runs `cyrius test`, a `--agnos` cross-compile gate, and `cyrius fuzz`.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench

## Consumers

Intended: **aethersafha** (compositor) — instantiates bhumi as its platform
backend (output/input/seat). Not wired yet (M4 / v0.5.0 acceptance gate).

## Next

See [`roadmap.md`](roadmap.md).
