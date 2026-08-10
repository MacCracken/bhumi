# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Fixed — two function-local `var X[N]` sizings, both writing past their own frames

⛔⛔ The same Cyrius trap twice: **function-local `var X[N]` allocates N BYTES**, not N u64s.
- `programs/backend-demo.cyr` declared `var evs[32]` — 32 bytes — and then authorised
  `bhumi_backend_poll(be, &evs, 32, now)` to write **32 events = 256 bytes** into it, 224 past the end and
  straight over `frame`, `fb`, `be`, `now` and the return address. Invisible on the host, because the
  non-agnos `_bhumi_kbscan` arm returns no events — but CI cross-compiles this for agnos, where the very
  first poll drains the whole agnsh-prompt scancode backlog. Now `var evs[256]`.
- `tests/bhumi.tcyr`'s pointer-decode block had `var prec[2]` for a **16-byte** kernel record (and wrote
  `store32(&prec + 12, ...)` into it) and `var ptev[4]` for a 32-byte event budget — roughly 40 bytes of
  its own frame overwritten. ⚠ The asserts passed anyway, which is the worst form of this bug: a green
  test standing on a corrupted stack. Now `[16]` and `[32]`.

⚠ Both found by an adversarial audit of the pointer chain, not by a failing test — neither could fail on
the host, and the one that could fail on agnos is an acceptance artifact nobody runs there.

## [1.1.4] - 2026-08-08 — the POINTER seam: `ptrscan #98`, a kind-tagged event, and a capability gate

### Added — `src/ptrscan.cyr`, the pointer counterpart to `kbscan.cyr`

⭐ **One merged sample, not a stream.** agnos `ptrscan #98` returns a 16-byte record — `s32 dx`, `s32 dy`
(**positive = DOWN**), `u32 buttons` (current level), `u32 buttons_seen` (OR since the last drain) — and
`bhumi_pointer_poll` decodes it into events. Pointer motion is a RELATIVE DELTA, so the useful unit is
the sum since you last asked; the kernel folds every HID report and this reads the fold. Streaming raw
reports would have moved the coalescing hazard into userland instead of fixing it. ⚠ `buttons_seen` is
what lets a click that starts *and finishes* inside one frame survive.

⛔ **It must never share the scancode pipe, at either end.** A one-pixel-right motion is `dX = 0x01`, and
`0x01` through `_bhumi_set1_to_hid` is HID `0x29` = **Escape**, which aethersafha maps to quit — so
pointer bytes on `kbscan #42`'s ring would mean *moving the mouse closes the desktop*, and that ring also
feeds cyrius-doom. Separate syscall, separate ring, separate decode.

### Added — an event KIND tag, with KEY as kind 0

⛔ **The batch is now MIXED, and an untagged pointer event reads as a keystroke.** `bhumi_key_usage` is
the low byte of dx, and `bhumi_key_pressed` is bit 8 of dx — so a horizontal motion of **297 px**
(`0x129`) is a *pressed* Escape, the same quit, one layer up. ⚠ Derived rather than assumed: a first test
used dy=41 and passed with the guard removed, because dy lives in bits 24-47 and cannot reach bit 8. Kind lives in bits
56-59 and **KEY is 0**, chosen so every event this library has ever produced is **bit-for-bit unchanged**
and no existing producer needed an edit (asserted directly: `bhumi_key_event(1, 0x29) == 0x129`).
`BHUMI_EV_MOTION` carries dx/dy as **signed 24-bit** fields — Cyrius has no sized ints, so the sign is
masked in and extended out by hand; without that, `dx = -1` becomes `+16777215` and the cursor teleports
right instead of moving one pixel left.

### Added — `BHUMI_DEV_POINTER = 4` is activated, and the drain is gated on it

⭐ **Pointer events are opt-in, structurally.** Every capability minted anywhere in this tree today is
`OUTPUT|INPUT` = 3, so a consumer that has not asked for `BHUMI_DEV_POINTER` receives exactly what it
received before. The **gate**, not consumer discipline, is what makes a mixed batch safe to ship.
⚠ Pointer events ride the SAME batch as keys — a second poll would double the syscall count per frame and
let the streams desynchronise, so a click could be delivered against a different frame than the motion
that positioned it. `max_ev - w` is the shared budget `kbscan.cyr` already uses.

### ⚠ A sizing trap this release had to survive, recorded because it will recur

`bhumi_pointer_poll`'s kernel record buffer is `var rec[16]` — **16 BYTES**. It was briefly `var rec[2]`,
carrying a comment that read *"function-local: 2 * 8 = 16 bytes"*: that is the **module-scope** rule
(`var X[N]` = N*8), applied to a **function-local** (where `var X[N]` = N bytes). A 16-byte kernel write
therefore landed in a 2-byte frame slot. agnos had the identical mistake in `#98`'s own buffer.

⚠ **The symptom pointed away from the cause**: buttons worked and motion did not, so the chain read as
half-plumbed and the hunt went through QEMU mouse selection, `info mice`, and the syscall's reachability
first. The tell in hindsight is that the two fields reading as garbage were the FIRST two — the ones
inside a 2-byte slot's blast radius. ⚠ No host test can reach this line: it is the one that talks to the
kernel, and the off-target arm returns 0.

⇒ When declaring a buffer for a fixed-size ABI record, write the BYTE COUNT and say so. Never compute it
as `n * 8`, and re-derive from scope rather than trusting a nearby comment.

### Changed — cyrius pin 6.5.5 → **6.5.13**

`sys_ptrscan` / `SYS_PTRSCAN` land there. ⚠ `src/ptrscan.cyr` is also added to `[lib].modules`: that list
is what `cyrius distlib` concatenates for consumers, so omitting it would have shipped a materialized
`lib/bhumi.cyr` with no pointer code and no error.

**Tests** 220 → **247 asserts**, mutation-verified in both directions: dropping the s24 sign extension
fails 6 (including `dx = -1` reading as 16777215), and collapsing the kind tag fails 4 — among them the
line that exists for exactly this, *"dy=41 is tagged MOTION, not read as HID 0x29 (Escape)"*.

## [1.1.3] - 2026-08-02

### Fixed — ⛔ `bhumi_output_query` RETURNED THE KERNEL'S 0 WHILE PROMISING 24, so every agnos caller read success as failure

agnos `#38 fbinfo` fills the 24-byte geometry struct and returns **0** — the display band's usual
0-ok convention (`agnos kernel/core/syscall.cyr`). This function's own doc comment has always said
*"Returns bytes written (24) on success"*, and its agnos arm was `return _bhumi_kfbinfo(info);` —
the kernel's 0, straight through.

⛔ **Every consumer in the ecosystem tests `== BHUMI_FBINFO_SIZE`**, so on agnos every one of them
treated a perfectly good answer as "no framebuffer": `aethersafha`'s `ae_query_geometry` fell back
to its hardcoded **1280x720** on a panel whose scanout is **800x600**, and `programs/scanout-demo`
and `programs/backend-demo` would never have printed geometry on agnos either.

⚠ **The consequence was silent and it defeated a fix written specifically to prevent it.**
aethersafha 0.10.0 shipped "THE COMPOSITOR WAS SIZED 1.6x WRONG FOR THE PANEL", whose entire point
was to stop assuming 1280x720 and *ask* — and the asking never worked on hardware. `#39 blit` clips
rather than errors, so a 1280x720 desktop on an 800x600 surface just shows its top-left corner with
nothing logged.

⚠ **Invisible off agnos, which is why it survived every test.** On a host `_bhumi_kfbinfo` returns
-1, which is *also* `!= 24`, so the fallback is correct there and the suite agrees. Only the agnos
arm was wrong, and only an iron burn could show it: the 2026-08-02 archaemenid boot printed
`gpu: console geometry matched to surface 800x600` and then, four lines later, the compositor
printing `1280` / `720`.

**Fix:** the translation moves into the portable half via a new pure `_bhumi_fbinfo_rc(rc)` —
negative stays -1, anything else becomes `BHUMI_FBINFO_SIZE`. One place knows the kernel's
convention, and callers get the contract that was always documented.

⭐ **`_bhumi_fbinfo_rc` is deliberately free of `#ifdef` so the host can assert it** (3 new cases,
220 tests total). The bug's whole shape was "the only wrong arm is the one no test machine runs", so
the mapping is now factored to exactly where a test can reach it.

## [1.1.2] - 2026-08-02

### Changed — cyrius pin 6.4.71 -> 6.5.5

Toolchain catch-up across the whole desktop stack, cut together so the next burn runs binaries built
by ONE compiler rather than 6 different ones.

⚠ **The pin was documentation, not enforcement.** `cyrius build` compiles with the INSTALLED `cycc`,
prints a `toolchain drift` warning, and carries on — so this project was already being built by 6.5.5
before this bump. Verify provenance with `~/.cyrius/versions/<pin>/bin/cyrius` when it matters.

⭐ What the gap actually contained, for a reader deciding whether to care:
- **6.5.1** made overload-suffix arity a hard **error** where it used to warn. Latent arity
  mismatches are now build failures instead of silently-wrong code — good, and the reason this
  sweep surfaced real defects elsewhere in the stack.
- **6.4.75** fixed `fn_table` growth past 8192 silently corrupting six fn-indexed side tables.
- **6.5.0** added file-scoped `private` / per-item `public` — the first real answer to this
  ecosystem's duplicate-`fn`-silently-shadows hazard.
- **6.4.82** completed the agnos GPU syscall wrapper band to `#82`-`#95`, so `sys_gpu_shader_op`
  (#92) and `sys_gpu_modeset_op` (#93) no longer need a raw `syscall()` behind an `#ifdef`.

### Verification

Host + `--agnos` builds green; 1 suite passes; `distlib` regenerated.

## [1.1.1] - 2026-07-23

### Changed — cyrius pin 6.3.34 → 6.4.71

Toolchain refresh across the draw stack. Materialised `lib/` re-synced (`cyrius lib sync --full`).
No source change; build + tests green at the new pin.

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
