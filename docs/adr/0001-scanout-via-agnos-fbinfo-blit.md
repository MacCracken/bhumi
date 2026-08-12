# 0001 — Scan out via the agnos fbinfo/blit syscalls

**Status**: Accepted — **partially superseded by [0003](0003-linux-is-a-real-display-target-fbdev-first.md)**
**Date**: 2026-07-02

> ⚠ **SCOPE OF THE SUPERSESSION, because "Superseded" alone would mislead.** Everything this ADR decides
> about **agnos** stands unchanged and is still the shipped mechanism: `#38 fbinfo` / `#39 blit`, the
> 24-byte struct, `dstxy = 0` for a full-screen present, and the BGRX pixel-format contract.
> **Only one clause is reversed** — *"Non-agnos targets get stub wrappers that return -1"*, below.
> Linux is a real display target as of 1.2.0; macOS and Windows keep the -1 stub. See ADR 0003.

## Context

M1 (the output module) must get a finished framebuffer onto the physical
display. The agnos kernel exposes exactly two syscalls for this, landed in agnos
1.51.0 and wrapped in the cyrius stdlib from 6.3.34:

- **`fbinfo` (#38)** — `sys_fbinfo(buf, len)` writes a 24-byte geometry struct:
  six little-endian u32 — `width`, `height`, `pitch` (bytes/scanline), `bpp`
  (=32), `pixel_format` (0=RGBX, 1=BGRX), `flags` (bit 0 = present).
- **`blit` (#39)** — `sys_blit(src, w, h, dstxy)` raw-copies a w×h 32bpp block to
  the framebuffer. No format conversion. `dstxy` packs `x = dstxy & 0xFFFF`,
  `y = (dstxy>>16) & 0xFFFF`, `scale = (dstxy>>32) & 0xFF` (kernel treats scale 0
  as 1×). Returns -1 only when no framebuffer is present.

(Verified against `agnos kernel/core/syscall.cyr`.) There is no higher-level
agnodrm mode-setting surface between bhumi and these syscalls — for a single
fixed-mode scanout target, the syscalls *are* the surface. bhumi also builds and
unit-tests on a Linux host, where #38/#39 mean unrelated Linux syscalls, so the
scanout calls cannot be compiled unconditionally.

## Decision

Scan out through `src/scanout.cyr`, calling the stdlib `sys_fbinfo` / `sys_blit`
wrappers behind `#ifdef CYRIUS_TARGET_AGNOS`. ~~Non-agnos targets get stub
wrappers that return -1 ("no framebuffer")~~ — **reversed for Linux at 1.2.0 by
[ADR 0003](0003-linux-is-a-real-display-target-fbdev-first.md); macOS and Windows still do** — so all
logic above the two thin wrappers is portable and host-testable. ⭐ That portability is what made ADR
0003 cheap: the Linux arm filled in these same two functions and changed nothing above them. Scope, in:

- `bhumi_output_present(fb)` blits at the **origin, unscaled** — `dstxy = 0`
  (x=0, y=0, scale=0→1×). Full-screen present needs no `dstxy` encoding
  knowledge; `0` is correct on any packing.
- `bhumi_output_query(info)` + `bhumi_fbinfo_*` accessors expose the geometry
  struct; `bhumi_output_format_ok(info)` reports byte-order compatibility.
- **Pixel-format contract**: `BhumiFb` stores XRGB8888 via `store32`, i.e. memory
  bytes `[B,G,R,X]` — which is agnos **BGRX (pixel_format 1)**. A raw blit is
  color-correct against a BGRX framebuffer; callers verify with
  `bhumi_output_format_ok` before presenting.
- The vendored stdlib (`lib/`) is synced to the 6.3.34 snapshot (via
  `cyrius lib sync`) so the wrappers exist; the `cyrius.cyml` pin moved
  6.3.5 → 6.3.34 to match, retiring the toolchain-drift warning.

## Consequences

- **Positive** — the scanout path is real and cross-target-verified: the agnos
  build emits `syscall` with `eax=38`/`eax=39`; the host build returns -1 and
  stays fully testable. No fabricated ABI — every number is from the kernel.
- **Negative** — bhumi now pins a newer toolchain (6.3.34) and carries the byte-
  order contract as a caller responsibility. A framebuffer that reports RGBX
  (pixel_format 0) is not yet handled (see below).
- **Neutral** — end-to-end acceptance (a test pattern on a real/QEMU framebuffer)
  still needs agnos hardware or an emulator; it is not reachable from the host CI.

## Alternatives considered

- **Raw `syscall(38/39, …)` numbers inside bhumi** — rejected: duplicates the
  stdlib's job and re-hardcodes numbers the stdlib already owns and verifies.
- **Wait for a higher-level agnodrm mode API** — rejected: for a single
  fixed-mode scanout, `fbinfo`+`blit` are the complete surface; a mode-setting
  layer is not needed for M1.
- **Swizzle R↔B inside `present()` to always be format-correct** — deferred: the
  common framebuffer is BGRX (raw-correct); an RGBX swizzle path can land if a
  real target reports pixel_format 0. Exposed the mismatch via
  `bhumi_output_format_ok` rather than silently converting.
