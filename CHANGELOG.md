# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

## [0.4.0] — 2026-07-02

**M3 — Seat (capability-gated device access).** The sovereign logind/DRM-master
replacement: device access is gated on a capability held by the active seat — no
uids, no logind, no setuid helper. bhumi *enforces* capabilities; sigil issues and
kavach sandboxes ([ADR 0002](docs/adr/0002-seat-lean-capability-enforcer.md)).

### Added
- `src/seat.cyr` — the seat / device-access gate. A `BhumiCap` (subject, device
  bitmask, expiry, issuer, reserved signature slot) and a `BhumiSeat` (id, active,
  held cap); every device op routes through the gate — `bhumi_seat_present` /
  `bhumi_seat_poll` succeed only for an **active** seat holding a capability that
  grants that device and hasn't expired, else `BHUMI_SEAT_DENIED`. A background
  seat cannot read keystrokes or touch the framebuffer.
- `src/seat.cyr` — `BhumiSeatMgr`, a registry over N seats that guarantees
  **exactly one active seat** across arbitrary hand-offs: `bhumi_seatmgr_switch`
  deactivates the current foreground before activating the target,
  `bhumi_seatmgr_release` drops to no-foreground (locked). `bhumi_seat_handoff`
  remains the pairwise primitive.
- `programs/seat-demo.cyr` — the M3 acceptance artifact: two seats + capabilities;
  the trace shows device access following the foreground across switches, with
  background seats DENIED. Pure/portable (host + agnos).
- `tests/bhumi.tcyr` — +56 assertions over `seat.cyr` (capability scope/expiry,
  active-AND-capability gate, hand-off, gated present/poll, seat-manager
  single-active + capacity); 173 total.
- `fuzz/bhumi.fcyr` — extended with the seat gate: random switch/release/grant
  sequences hold at-most-one-active, manager/active consistency, and
  background-always-denied (200k+ iterations).

**M2 — Input (keyboard).** The compositor's events-in path: drain the USB/xHCI
HID keyboard via the agnos `kbscan`#42 syscall and normalize it into a key-event
stream. Keyboard-only — agnos exposes no pointer syscall yet, so pointer input is
deferred (agnos has no PS/2 and never will). Verified cross-target; on-hardware/
QEMU acceptance via `input-demo` is the downstream step (see roadmap M2).

### Added
- `src/input.cyr` — the HID-decode half of the input module. A normalized
  key-event model (`bhumi_key_event` + `bhumi_key_{pressed,usage}`) over **USB
  HID usage codes** (Keyboard/Keypad page 0x07), and `bhumi_kbd_diff`, which
  diffs two 8-byte HID boot keyboard reports into press/release events — release
  is *derived* from report state (HID reports are state-based), not a wire
  signal. Handles modifiers (0xE0-0xE7), held keys, and empty/rollover slots.
  bhumi emits physical key events; layout/keysyms stay in the compositor.
- `src/kbscan.cyr` — the kernel-drain half. Pulls HID reports via `kbscan`#42
  and runs them through the decoder: `bhumi_input_poll(prev, out, max)` drains +
  diffs, `bhumi_input_process` is the pure host-tested report-stream core,
  `bhumi_input_init` seeds the held report. The `sys_kbscan` wrapper is behind
  `#ifdef CYRIUS_TARGET_AGNOS`; the host stub returns 0. Verified cross-target:
  the `--agnos` build emits `syscall` `eax=42`.
- `programs/input-demo.cyr` — the M2 acceptance artifact: on agnos it polls the
  keyboard and prints each key (down/up + HID usage, Esc quits); off agnos it
  explains itself and exits. Builds `--agnos`; emits `kbscan`#42 + `sleep_ms`#41.
- `tests/bhumi.tcyr` — +31 assertions over `input.cyr` / `kbscan.cyr` (event
  packing, report diff for press/release/modifiers/held-keys/rollover, drain
  processing of multi-report buffers, host-stub poll); 117 total.
- `fuzz/bhumi.fcyr` — extended with the HID report decoder: random 8-byte reports
  through `bhumi_kbd_diff` hold the event-count bound, usage/pressed validity, and
  self-diff-is-empty invariants (200k+ iterations).

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
