# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [1.1.1] - 2026-07-23

### Changed — cyrius pin 6.3.34 → 6.4.71

Toolchain refresh across the draw stack. Materialised `lib/` re-synced (`cyrius lib sync --full`).
No source change; build + tests green at the new pin.

## [Unreleased]

## [1.1.0] — 2026-07-08

Keyboard input now works on agnos. First backward-compatible feature release
since the 1.0 API freeze (one added public function; the 70 frozen symbols are
untouched).

### Fixed

- **agnos keyboard input.** `bhumi_input_poll` decoded 8-byte USB **HID reports**
  on every target, but agnos `kbscan`#42 delivers raw AT/XT **Set-1 scancodes**
  (the same pipe cyrius-doom's `input_poll` drains). So keyboard input through
  bhumi never produced correct events on agnos. `bhumi_input_poll` now branches by
  target: agnos → Set-1 decode; host → the HID-report path (a no-op — no
  keyboard). The host HID decode (`bhumi_input_process`) is unchanged.

### Added

- **`bhumi_scancode_process(raw, n, out, max_ev)`** (`src/kbscan.cyr`) — a pure,
  host-testable AT/XT **Set-1 scancode** decoder: make/break (bit 7) +
  `0xE0`-extended → the same normalized HID-usage key events
  (`bhumi_key_event`) the compositor already consumes. Tables derived from the
  AT/XT Set-1 layout + the USB HID Usage Table (Keyboard/Keypad page `0x07`);
  covers the main block, the function row (F1–F12), and common extended keys
  (arrows / nav / RCtrl / RAlt). The Set-1 counterpart to `bhumi_input_process`.
- New **"Set-1 scancode decode"** test group (Tab/Esc/F4–F6, a letter, a `0xE0`
  arrow, multi-key, break codes) — suite **217/217**.

### Validated

- On real agnos (QEMU + KVM + `qemu-xhci`/`usb-kbd`): a `sendkey tab` produced
  HID usage `0x2B` in the aethersafha compositor loop and drove its focus — the
  full chain (usb-kbd → xHCI → `hid_poll` → `kb_buf` → `kbscan`#42 → Set-1
  decode → HID usage → `input_map`). Multi-key delivery reliability under a
  ring-3 render loop is a separate agnos-kernel concern (xHCI-HID service), not
  bhumi's.

## [1.0.0] — 2026-07-02

**First stable release.** All six v1.0 criteria are met — the final one, a live
downstream consumer, closed by **aethersafha 0.1.0** wiring bhumi in as its
platform backend. The public API (70 functions, [`docs/api.md`](docs/api.md)) is
frozen and CI-enforced; a compositor now drives real pixels-out, events-in, and a
capability-gated seat through bhumi.

The sovereign replacement for the Linux DRM/KMS + libinput + logind backend trio,
built greenfield from a `cyrius init` scaffold across M1–M4:

- **Output** — `BhumiFb` framebuffer → agnos `fbinfo`#38 / `blit`#39 ([ADR 0001](docs/adr/0001-scanout-via-agnos-fbinfo-blit.md))
- **Input** — USB HID keyboard → `kbscan`#42 (report-diff decode; no PS/2)
- **Seat** — capability-gated device access, one active seat, no logind/uids ([ADR 0002](docs/adr/0002-seat-lean-capability-enforcer.md))
- **Backend** — the single `BhumiBackend` handle a compositor drives a frame loop against

Verified: 200 assertions + fuzz (200k iters) + a pre-release adversarial review;
five programs cross-compile `--agnos`; security audit clean (0 critical/high);
benchmarks captured. Deferred to future releases: pointer input (awaits a kernel
pointer syscall) and multi-seat orchestration.

### Changed
- No API changes since 0.7.0 — 1.0.0 promotes the frozen 0.7.0 surface to stable.

## [0.7.0] — 2026-07-02

**Public API frozen.** The 70-function surface is now a stable, documented,
machine-enforced contract.

### Added
- `docs/api.md` — the frozen public API reference: 70 functions + semantic
  constants across output / scanout / pattern / input / kbscan / seat / backend,
  grouped by module with signatures.
- `scripts/api-surface.sh` — enforces the frozen surface against `dist/bhumi.cyr`
  (hardcoded manifest, so a deletion can't silently pass), wired into CI as the
  "API surface (frozen)" gate. Removing or renaming a public symbol now fails the
  build. Satisfies the v1.0 API-frozen criterion.

## [0.6.0] — 2026-07-02

### Added
- `docs/benchmarks.md` — captured microbenchmarks for the hot paths on a
  Ryzen 7 5800H: `seat_can` gate 9 ns, `fb_set` 13 ns, `kbd_diff` 59 ns,
  `fb_clear` 975 µs/720p-frame, pattern generators ~20 ms/frame (per-pixel,
  diagnostic). Satisfies the v1.0 benchmarks criterion.
- `tests/bhumi.bcyr` — expanded from pattern-only to also benchmark `fb_clear`,
  `fb_set` (bounds-checked pixel), `kbd_diff` (HID decode), and `seat_can` (the
  gate), with a noop clock baseline.

## [0.5.1] — 2026-07-02

### Added
- `bhumi_cap_verify` — optional capability-provenance verification, the reserved
  `BHUMI_CAP_SIG` hook anticipated by [ADR 0002](docs/adr/0002-seat-lean-capability-enforcer.md).
  `bhumi_cap_signed_bytes` serializes a capability's authenticated fields
  (subject|devices|expiry|issuer, 32 bytes LE) and `bhumi_cap_verify(cap,
  verify_fn, pubkey)` calls a **caller-supplied** Ed25519 verifier (e.g. sigil's
  `ed25519_verify`) through a function pointer — bhumi embeds no crypto and no
  keystore. Plus `bhumi_cap_set_sig` / `bhumi_cap_sig`. Opt-in: the default seat
  gate stays possession-based. Adds the `fnptr` stdlib dep. +12 tests (200).
- `docs/audit/2026-07-02-audit.md` — the first formal security audit (adversarial
  review + code-pattern scan + fuzz + cross-target ABI verification). 0
  critical/high; F-1 (null-capability crash) fixed in 0.5.0; F-2 (lean-enforcer
  trust) documented and mitigated by the new verify hook. Satisfies the v1.0
  "security audit pass" criterion.

## [0.5.0] — 2026-07-02

**M4 — Assembled backend.** output + input + seat fold into one `BhumiBackend`
handle a downstream consumer drives a frame loop against — the last roadmap
milestone. This makes bhumi a *usable* backend rather than three modules.

### Added
- `src/backend.cyr` — the assembled backend: the single `BhumiBackend` handle
  aethersafha instantiates. `bhumi_backend_open(cap, w, h)` folds a primary
  framebuffer (M1), an input cursor (M2), and an owned foreground seat (M3) into
  one handle; the frame-loop API — `bhumi_backend_fb` / `_poll` / `_present`,
  with `_activate` / `_deactivate` for VT-switch — routes every device op through
  the seat gate, so a backgrounded backend is DENIED.
- `programs/backend-demo.cyr` — the M4 acceptance artifact: an aethersafha
  stand-in driving a `poll → draw → present` frame loop through one handle, then
  a backgrounded frame DENIED. The `--agnos` build emits all three device
  syscalls (`fbinfo`#38, `blit`#39, `kbscan`#42).
- `tests/bhumi.tcyr` — +15 assertions over `backend.cyr` (open/geometry, gated
  frame-loop ops, VT-switch DENIED, scoped-capability, null-cap safety); 188.
- `fuzz/bhumi.fcyr` — extended with the backend gate (backgrounded ⇒ DENIED).

### Fixed
- `bhumi_backend_open` / `bhumi_cap_subject` — null-capability crash. A null `cap`
  (e.g. `bhumi_cap_new` returned 0 on OOM) was dereferenced at address 0 instead
  of returning 0 per contract. Both now guard `cap == 0`. Found by the
  pre-release adversarial review.

### Removed
- `bhumi_scaffold_ok` — the M0 scaffold sentinel in `src/main.cyr`, retired now
  that `src/backend.cyr` provides the real public surface.

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
