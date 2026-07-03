# bhumi — Current State

> Refreshed every release. CLAUDE.md is preferences/process/procedures
> (durable); this file is **state** (volatile).

## Version

**1.0.0** — first stable release; all six v1.0 criteria met (aethersafha 0.1.0
wired as the first live consumer). 0.7.0 froze the public API; 0.6.0 benchmarks;
0.5.1 verify hook + audit; M4 (backend) 0.5.0 completed the four milestones;
M3 0.4.0; M2 0.3.0; M1 0.2.0; scaffold 0.1.0.

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
M4 (v0.5.0). Verified cross-target (host: 188 assertions + fuzz + a pre-release
adversarial review; agnos: `backend-demo` emits `syscall` #38/#39 output, #42
input through one handle; the seat gate + backend are pure userland).
Visual/interactive acceptance (`scanout-demo`, `input-demo`, `seat-demo`,
`backend-demo`) is a manual downstream step, not reachable from host CI.
**Pointer input is deferred** — no pointer syscall exists (surface tops at
1.51.0), so input is keyboard-only.

**v1.0 reached** — all six criteria met (see [roadmap.md](roadmap.md)): frozen
API, test coverage, benchmarks, security audit, complete CHANGELOG, and a live
consumer (aethersafha 0.1.0). Post-1.0 work is request-driven: **pointer input**
when the kernel exposes a pointer syscall, the optional sigil verify path if the
threat model requires it, and multi-seat orchestration beyond the single seat.

## Tests

- `tests/bhumi.tcyr` — primary suite: smoke + `output` / `pattern` / `scanout` /
  `input` / `kbscan` / `seat` / `backend` + edge cases (200 assertions, passes on
  `cyrius test`). Source-includes `src/main.cyr` (see
  [architecture 001](../architecture/001-cyrius-test-const-visibility.md)).
- `fuzz/bhumi.fcyr` — property fuzz over the public output + input surface
  (`cyrius fuzz`); holds to 200k+ iterations.
- `tests/bhumi.bcyr` — benchmarks: 720p color-bars / XOR full-frame paint
  throughput (`cyrius bench tests/bhumi.bcyr`).
- CI runs `cyrius test`, a `--agnos` cross-compile gate, and `cyrius fuzz`.

## Dependencies

Direct (declared in `cyrius.cyml`):

- stdlib — string, fmt, alloc, io, vec, str, syscalls, assert, bench, fnptr

## Consumers

**aethersafha 0.1.0** (compositor) — wired: instantiates bhumi as its platform
backend (output/input/seat) via `bhumi_backend_open` and drives a frame loop
through the single handle. The first live downstream consumer; closed the last
v1.0 criterion.

## Next

See [`roadmap.md`](roadmap.md).
