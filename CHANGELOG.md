# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `src/input.cyr` — the HID-decode half of the M2 input module. A normalized
  key-event model (`bhumi_key_event` + `bhumi_key_{pressed,usage}`) over **USB
  HID usage codes** (Keyboard/Keypad page 0x07), and `bhumi_kbd_diff`, which
  diffs two 8-byte HID boot keyboard reports into press/release events — release
  is *derived* from report state (HID reports are state-based), not a wire
  signal. Handles modifiers (0xE0-0xE7), held keys, and empty/rollover slots.
  bhumi emits physical key events; layout/keysyms stay in the compositor.
  Keyboards attach over USB/xHCI HID (agnos has no PS/2). The `kbscan`#42 kernel
  drain seam is next; pointer input is deferred (no pointer syscall yet). +22
  tests (108).

## [0.2.0] — 2026-07-02

**M1 — Output.** The compositor's pixels-out path: allocate a software
framebuffer, draw into it, and scan it out to the agnos display. Code-complete
against the real kernel ABI and verified cross-target; on-hardware/QEMU visual
acceptance is the downstream step (see roadmap M1).

### Added
- `src/output.cyr` — the pixel-production half of the output module: a
  heap-owned software framebuffer (`BhumiFb`) in XRGB8888. Public surface:
  `bhumi_fb_new` / `bhumi_fb_{width,height,pitch,format,bpp,pixels,size}`,
  bounds-checked `bhumi_fb_set` / `bhumi_fb_get` (out-of-bounds rejected, never
  clamped), `bhumi_fb_clear`, and the `bhumi_xrgb` pixel packer.
- `src/scanout.cyr` — the kernel handoff completing the output path. Scans a
  `BhumiFb` out to the display via the agnos `fbinfo` (#38) and `blit` (#39)
  syscalls: `bhumi_output_present(fb)` (origin blit, `dstxy=0`),
  `bhumi_output_query(info)` + `bhumi_fbinfo_*` geometry accessors, and
  `bhumi_output_format_ok(info)` (BGRX byte-order check). The two kernel
  wrappers are behind `#ifdef CYRIUS_TARGET_AGNOS`; non-agnos hosts get stubs
  returning -1, keeping everything above them portable and host-tested. Verified
  cross-target: the `--agnos` build emits `syscall` with `eax=38`/`eax=39`. See
  [ADR 0001](docs/adr/0001-scanout-via-agnos-fbinfo-blit.md).
- `src/pattern.cyr` — bring-up test patterns over a `BhumiFb`: SMPTE-style
  100% color bars (`bhumi_pattern_bars`, with public `bhumi_bar_color` /
  `bhumi_bar_index`) and a grayscale XOR gradient (`bhumi_pattern_xor`, with
  public `bhumi_xor_value`). (Solid fill is `bhumi_fb_clear`.)
- `programs/scanout-demo.cyr` — the M1 acceptance artifact: queries the display
  geometry (720p fallback off-agnos), draws color bars sized to the screen, and
  presents them. On a real/QEMU agnos target the console shows the bars.
- `tests/bhumi.tcyr` — 84 assertions across `output.cyr` / `pattern.cyr` /
  `scanout.cyr` + edge cases (+ smoke = 86 total on `cyrius test`): geometry &
  dim rejection, set/get bounds, clear, bar table/paint, XOR values, fbinfo
  struct parsing, format compatibility, present/query guards, 1×1 + max-dim
  boundaries, uneven bar widths, present-flag masking.
- `fuzz/bhumi.fcyr` — property fuzz over the public output surface (`cyrius
  fuzz`): framebuffer bounds round-trip, `bhumi_xrgb` masking, bar-index range,
  pattern-pixel and fbinfo accessor invariants. Holds to 200k+ iterations.
- `tests/bhumi.bcyr` — real benchmarks: 720p `pattern_bars` / `pattern_xor`
  full-framebuffer paint throughput (replaces the no-op stub).
- `docs/adr/0001-scanout-via-agnos-fbinfo-blit.md` — ADR for the scanout ABI
  decision. `docs/architecture/001-cyrius-test-const-visibility.md` — why a
  `.tcyr` must source-include `src/main.cyr` to name a module constant.
- CI: an `--agnos` cross-compile gate (smoke + scanout-demo) and a `cyrius fuzz`
  step, so the agnos scanout path and the invariants can't regress unseen.

### Changed
- Toolchain pin `cyrius.cyml [package].cyrius` 6.3.5 → 6.3.34 and re-vendored
  `lib/` via `cyrius lib sync` (agnos surface 1.45.16 → 1.51.0), bringing the
  `sys_fbinfo`/`sys_blit` wrappers and retiring the pin-drift warning.

### Removed
- `tests/bhumi.fcyr` — misplaced no-op scaffold stub (`cyrius fuzz` reads
  `fuzz/*.fcyr`); replaced by the real `fuzz/bhumi.fcyr`.

## [0.1.0] — 2026-06-29

### Added
- Initial project scaffold (`cyrius init --lib --agent`, pin 6.3.5).
- Project identity: sovereign userland **platform backend** for the AGNOS
  compositor (aethersafha) — the replacement for the Linux DRM/KMS + libinput
  + logind backend trio against the agnos kernel. Explicitly **not** XWayland
  and **not** a client-compat bridge (that is `mehman`).
- Architecture map in `src/main.cyr`: planned `output` (agnodrm scanout) /
  `input` (kernel `hid_poll`) / `seat` (sigil/kavach gate) / `backend`
  (assembled handle) modules.
