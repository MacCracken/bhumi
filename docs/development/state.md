# bhumi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.4.0** (2026-08-12) — ⭐⭐ **Linux POINTER over evdev** (motion + buttons), sharing ONE drain with the
keyboard because on Linux both arrive on the same fds and a read consumes. QEMU-proven through the
emulated USB mouse: cursor moved by exactly the injected delta, click routed. ⛔ The device scan latched
TWICE (scan-once, then retry-while-empty) and each latch silently lost a whole input device; it now
rescans by index. ⚠ Unplug still unhandled.

**1.3.0** (2026-08-12) — ⭐⭐ **Linux KEYBOARD over evdev.** `/dev/input/event*` -> `EV_KEY` -> Set-1 ->
HID. Proven in QEMU through the emulated input device (QMP `send-key esc` -> usage 41), negative-
controlled. ⛔ **Base plane only** — evdev emits no 0xE0 prefix, so arrows/RCtrl/Meta/Home/End/PgUp/
PgDn/Insert/Delete are unmapped and dropped until a second table lands. ⚠ Pointer still stubbed.

**1.2.1** (2026-08-12) — ⛔ **1.2.0's Linux arm displayed nothing on shadow-buffer fbdevs.** It used
`mmap` + stores, correct on amdgpu (real scanout memory) and silently a no-op on `simpledrm` and
anything on `drm_fbdev_shmem`, where a store damages nothing and the shadow is never flushed.
Now `pwrite` on every driver — one syscall for a full-screen present, per-row for partial blits.
⚠ **One machine was the blind spot, not one weak test**: 1.2.0's oracle was already an external fd,
and it still missed this because the second reader went through the same shadow. Found in QEMU.
⚠ Operational constraint discovered with it: a shadow-buffer fbdev is flushed only while it is
ACTIVELY DRIVEN — a guest booted `console=ttyS0` alone, or with `quiet`, never reaches scanout even
via `pwrite`, because fbcon never does its first draw.

**1.2.0** (2026-08-12) — ⭐⭐ **Linux is a real display target.** `src/scanout.cyr` grows an fbdev arm:
geometry from sysfs, pixels via `mmap` of `/dev/fb0`. Verified at 2560x1440 through an
independent-fd readback oracle. Charter change: [ADR 0003](../adr/0003-linux-is-a-real-display-target-fbdev-first.md);
`roadmap.md`'s *"Out of scope: Non-AGNOS targets"* struck; ADR 0001 partially superseded.
⚠ **fbdev first, DRM/KMS later** — the seam was already fbdev-shaped. macOS/Windows keep the `-1` stub
deliberately.

Trail: 1.1.5 two `var X[N]` byte-sizing fixes · 1.1.4 pointer input (`ptrscan.cyr`, `#98`) · 1.1.3 the
`_bhumi_fbinfo_rc` 0-vs-24 fix · 1.0.0 first stable · 0.7.0 froze the public API · 0.6.0 benchmarks ·
0.5.1 verify hook + audit · M4 0.5.0 · M3 0.4.0 · M2 0.3.0 · M1 0.2.0 · scaffold 0.1.0.

⛔ **This block said "1.0.0 … aethersafha 0.1.0 as the first live consumer" until 2026-08-12** — five
releases and a whole input subsystem stale, while the consumer was at **0.13.1**. A state file that
lags its own repo by five versions is read as current by the next session; refresh it AT the cut.

## Toolchain

- **Cyrius pin**: `6.5.20` (in `cyrius.cyml [package].cyrius`), matching the active toolchain.
  ⚠ Was recorded here as `6.3.34` while the manifest said `6.5.13` and `cycc` was `6.5.20` — three
  different answers to one question. **Read the manifest, not this line**, and re-sync both at a cut.
- `cyrius lib sync --full` is required after a pin bump (107-file snapshot).
- **`[deps].stdlib` is unchanged by the Linux arm** — `sys_open`/`sys_read`/`sys_close` come from
  `syscalls` and `memcpy` from `string`, both already declared. ⛔ `lib/mmap.cyr` is deliberately NOT
  used: its `mmap_file_rw` passes **MAP_PRIVATE**, which on a framebuffer writes to a copy-on-write
  page and displays nothing while reporting success.

## Source

- `src/main.cyr` — lib header + convenience entry (source-includes the domain modules).
- `src/output.cyr` — **M1.** Pixel-production half: a software `BhumiFb`
  framebuffer (XRGB8888) with construction, bounds-checked pixel set/get, clear.
- `src/scanout.cyr` — **M1.** Kernel handoff: scans a `BhumiFb` to the display
  via agnos `fbinfo`#38 / `blit`#39 (`bhumi_output_present` / `_query` /
  `_format_ok` + `bhumi_fbinfo_*`). Kernel calls are behind
  `#ifdef CYRIUS_TARGET_AGNOS`. ⭐ **1.2.0 adds a real `CYRIUS_TARGET_LINUX` arm** (fbdev: sysfs
  geometry + one `FBIOGET_VSCREENINFO`, `mmap` of `/dev/fb0`, word-at-a-time row copy); macOS/Windows
  keep the `-1` stub. Four flat, mutually exclusive guards. The pure half — sysfs parsing, struct
  packing, format derivation, blit clipping — is `#ifdef`-free and unit-tested with no device.
  Cross-target verified: the `--agnos` binary emits `syscall` `eax=38`/`39`; the Linux arm is proven by
  `programs/fbdev-probe.cyr` through an independent-fd readback.
  See [ADR 0001](../adr/0001-scanout-via-agnos-fbinfo-blit.md) and
  [ADR 0003](../adr/0003-linux-is-a-real-display-target-fbdev-first.md).
- `src/ptrscan.cyr` — **1.1.4.** Pointer drain: agnos `ptrscan #98` → one merged 16-byte sample decoded
  into kind-tagged MOTION/BUTTON events. ⛔ Deliberately NOT on the scancode pipe — `dX = 0x01` decodes
  through the Set-1 table as HID 0x29 = Escape, which the compositor maps to QUIT. Host arm returns 0.
  ⚠ This module was missing from this list entirely until 2026-08-12.
- `src/pattern.cyr` — **M1.** Bring-up test patterns over a `BhumiFb`:
  SMPTE-style color bars and a grayscale XOR gradient — the "known test pattern"
  of the M1 acceptance gate.
- `programs/scanout-demo.cyr` — **M1 acceptance artifact.** Queries geometry
  (720p fallback off-agnos), draws bars, presents. Runs on real/QEMU agnos.
- `src/input.cyr` — **M2.** Events-in: a normalized key-event model over **USB
  HID usage codes** (page 0x07) + `bhumi_kbd_diff`, which diffs 8-byte HID boot
  keyboard reports into press/release events (release derived from report state).
  Keyboards attach over USB/xHCI HID — agnos has no PS/2.
- `src/kbscan.cyr` — **M2.** Kernel drain: `bhumi_input_poll` pulls HID reports
  via agnos `kbscan`#42 and diffs them into events (`sys_kbscan` behind
  `#ifdef CYRIUS_TARGET_AGNOS`; host stub → 0). Cross-target verified: the
  `--agnos` binary emits `syscall` `eax=42`.
- `programs/input-demo.cyr` — **M2 acceptance artifact.** Polls the keyboard and
  prints each key (down/up + HID usage; Esc quits) on agnos; explanatory pass
  off-agnos.
- `src/seat.cyr` — **M3.** Sovereign device-access gate (logind/DRM-master
  replacement): `BhumiCap` (subject/devices/expiry/issuer) + `BhumiSeat`
  (id/active/cap) + `BhumiSeatMgr` (single-active registry). Device ops route
  through `bhumi_seat_present` / `_poll`, which only pass for an active seat
  holding a valid capability; `bhumi_seatmgr_switch` keeps exactly one active.
  bhumi *enforces* capabilities; sigil issues, kavach sandboxes
  ([ADR 0002](../adr/0002-seat-lean-capability-enforcer.md)). 0.5.1 adds the
  opt-in `bhumi_cap_verify` provenance hook (caller-supplied Ed25519; no crypto
  in bhumi).
- `programs/seat-demo.cyr` — **M3 acceptance artifact.** Traces device access
  following the foreground across hand-offs; background seats DENIED. Portable.
- `src/backend.cyr` — **M4.** The assembled `BhumiBackend` handle aethersafha
  instantiates: `bhumi_backend_open(cap, w, h)` folds a primary framebuffer +
  input cursor + owned foreground seat; `bhumi_backend_fb` / `_poll` / `_present`
  / `_activate` / `_deactivate` are the gated frame-loop API. (The M0
  `bhumi_scaffold_ok` sentinel is removed — backend.cyr is the real surface.)
- `programs/backend-demo.cyr` — **M4 acceptance artifact.** aethersafha stand-in:
  a `poll → draw → present` frame loop through one handle (`--agnos` emits
  `fbinfo`#38 / `blit`#39 / `kbscan`#42), then a backgrounded frame DENIED.

**All four roadmap milestones shipped** — M1 (v0.2.0), M2 (v0.3.0), M3 (v0.4.0),
M4 (v0.5.0). Verified cross-target (host: 288 assertions + fuzz + a pre-release
adversarial review; agnos: `backend-demo` emits `syscall` #38/#39 output, #42
input through one handle; the seat gate + backend are pure userland).
Visual/interactive acceptance (`scanout-demo`, `input-demo`, `seat-demo`,
`backend-demo`) is a manual downstream step, not reachable from host CI.
⛔ **"Pointer input is deferred — no pointer syscall exists, so input is keyboard-only" WAS WRONG FOR
FOUR RELEASES.** Pointer input **shipped in 1.1.4**: `src/ptrscan.cyr` (103 lines) drains agnos
`ptrscan #98`, and the consumer has iron-proven a titlebar drag on real hardware. ⚠ This is the
highest-consequence stale line the file carried — it told a consumer not to bother asking for something
that already worked. Retained in the past tense so it is not re-derived as a limitation.

**v1.0 reached** — all six criteria met (see [roadmap.md](roadmap.md)): frozen API, test coverage,
benchmarks, security audit, complete CHANGELOG, and a live consumer. Post-1.0 work is request-driven:
~~pointer input~~ (shipped 1.1.4), the optional sigil verify path if the threat model requires it, and
multi-seat orchestration beyond the single seat.
⭐ **Post-1.1 the charter changed**: Linux is a display target (1.2.0, ADR 0003). Remaining Linux work —
DRM/KMS as a second backend, evdev input, and a Linux seat notion — is tracked in
[roadmap.md](roadmap.md) under *In scope, not yet built*.

## Tests

- `tests/bhumi.tcyr` — primary suite: smoke + `output` / `pattern` / `scanout` /
  `input` / `kbscan` / `ptrscan` / `seat` / `backend` + the Linux fbdev arm's pure half + edge cases
  (**288 assertions** at 1.2.0, passes on `cyrius test`). ⛔ **No test may call `bhumi_output_present`
  with a real fb** — on Linux that writes to the physical display; the suite asserts the seat gate
  predicate instead, and a before/after `dd` of `/dev/fb0` confirms `cyrius test` leaves it
  byte-identical. Source-includes `src/main.cyr` (see
  [architecture 001](../architecture/001-cyrius-test-const-visibility.md)).
- `fuzz/bhumi.fcyr` — property fuzz over the public output + input surface
  (`cyrius fuzz`); holds to 200k+ iterations.
- `tests/bhumi.bcyr` — benchmarks: 720p color-bars / XOR full-frame paint
  throughput (`cyrius bench tests/bhumi.bcyr`).
- CI runs **four** gates: `cyrius test`, a `--agnos` cross-compile of all five programs, `cyrius fuzz`,
  and **API surface (frozen)** — `cyrius distlib` + `scripts/api-surface.sh`, which fails the build on a
  removed or renamed public symbol. ⚠ The fourth was missing from this line, so a contributor could
  believe a rename only failed locally. Host-builds `programs/fbdev-probe.cyr` for compile coverage but
  does not run it (no `/dev/fb0` on CI).

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench, fnptr

## Consumers

**aethersafha 0.13.1** (compositor; was recorded here as 0.1.0) — wired: instantiates bhumi as its platform
backend (output/input/seat) via `bhumi_backend_open` and drives a frame loop
through the single handle. The first live downstream consumer; closed the last
v1.0 criterion.

## Next

See [`roadmap.md`](roadmap.md).
