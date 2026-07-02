# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/en/1.1.0/).

## [Unreleased]

### Added
- `src/output.cyr` — the pixel-production half of the M1 output module: a
  heap-owned software framebuffer (`BhumiFb`) in XRGB8888. Public surface:
  `bhumi_fb_new` / `bhumi_fb_{width,height,pitch,format,bpp,pixels,size}`,
  bounds-checked `bhumi_fb_set` / `bhumi_fb_get` (out-of-bounds rejected, never
  clamped), `bhumi_fb_clear`, and the `bhumi_xrgb` pixel packer. The kernel
  scanout seam (agnodrm → `blit#39`) is deliberately deferred until that ABI
  lands (the agnos snapshot here tops out at 1.45.16 / `winsize#60`).
- `tests/bhumi.tcyr` — 27 assertions over `output.cyr` (geometry, dim rejection,
  set/get round-trip + bounds, clear).
- `docs/architecture/001-cyrius-test-const-visibility.md` — the first
  architecture note: why a `.tcyr` must source-include `src/main.cyr` to name a
  module constant under `cyrius test`.

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
