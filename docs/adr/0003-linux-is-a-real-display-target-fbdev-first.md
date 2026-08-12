# 0003 — Linux is a real display target, and fbdev comes before DRM/KMS

**Status**: Accepted
**Date**: 2026-08-12

## Context

bhumi shipped 1.0.0 → 1.1.5 as an agnos-only platform backend. Two committed documents said so:
[ADR 0001](0001-scanout-via-agnos-fbinfo-blit.md) decided that *"non-agnos targets get stub wrappers
that return -1"*, and `docs/development/roadmap.md` listed **"Non-AGNOS targets"** under *Out of scope
(for v1.0)*. The consumer agreed from its own side — aethersafha's `planning/desktop.md` carried a
three-substrate matrix assigning Linux *"protocol logic, layout maths, the render pipeline, every unit
suite"* while QEMU and iron carried every visual proof.

That was coherent, and it stopped being what the project wants. Measured in aethersafha on 2026-08-12:
**everything above the device seam already worked on Linux.** The AF_UNIX/SOCK_SEQPACKET wire, the
shared-buffer handoff, `CREATE_SURFACE → ATTACH_BUF → COMMIT`, window mint, composite, chrome, damage
band and exit teardown all ran, and two real clients connected and presented. The compositor produced a
correct frame in RAM every time and **nothing scanned it out**, because these two functions returned -1:

```cyrius
fn _bhumi_kfbinfo(info): i64 { return 0 - 1; }
fn _bhumi_kblit(src, w, h, dstxy): i64 { return 0 - 1; }
```

The operator ruled on 2026-08-12 that Linux is a real display target and that the out-of-scope stance is
no longer applicable.

⚠ **This is a charter change, not a discovery.** Nothing about the -1 stubs was broken; they were an
accurate implementation of a decision that has now been reversed.

## Decision

**Linux is a first-class display target for bhumi.** `src/scanout.cyr`'s seam grows a real
`#ifdef CYRIUS_TARGET_LINUX` arm, and the implementation order is **fbdev now, DRM/KMS later**.

**Why fbdev is not a compromise: this seam is already fbdev-shaped.** The mapping onto the two functions
ADR 0001 defined is 1:1 —

| bhumi seam | agnos | Linux |
|---|---|---|
| `_bhumi_kfbinfo` | `#38 fbinfo` → 24-byte geometry struct | geometry from sysfs + one `FBIOGET_VSCREENINFO` |
| `_bhumi_kblit` | `#39 blit` → raw 32bpp copy | `mmap` of `/dev/fb0` + row copy |

so the entire portable half of the module — the struct accessors, `_bhumi_fbinfo_rc`, the format
contract, `bhumi_output_present` — is reused unchanged and untouched.

**DRM/KMS with dumb buffers is the durable answer and is a SECOND backend behind this same interface.**
It is deferred rather than skipped: it needs buffer lifetime and page-flip semantics that
`_bhumi_kfbinfo`/`_bhumi_kblit` cannot express, so adopting it means growing the seam, not just filling
it in. Doing fbdev first gets pixels on screen without that redesign and proves every layer above.

Implementation specifics that are part of the decision:

- **Geometry from sysfs, not ioctl.** `/sys/class/graphics/fb0/{virtual_size,stride,bits_per_pixel}`
  supplies every field of the 24-byte struct as plain text, with no struct-layout risk.
- **Exactly one ioctl, for the one thing sysfs cannot answer.** `FBIOGET_VSCREENINFO` is issued solely
  to read the `red`/`blue` bit offsets and derive `pixel_format`. Guessing BGRX would silently swap red
  and blue on any framebuffer that is not the DRM default — a wrong picture, not an error. It fails
  soft to BGRX, because a compositor with slightly wrong colours beats one that refuses to start.
- **`MAP_SHARED`, never `MAP_PRIVATE`.** The cyrius stdlib's `mmap_file_rw` (`lib/mmap.cyr:100-104`)
  passes `MAP_PRIVATE`, which on a framebuffer yields a copy-on-write mapping: writes succeed, no error
  is reported, and nothing reaches the screen. The arm calls `mmap` directly to avoid it.
- **32bpp only.** bhumi's whole pixel contract is XRGB8888; a 16bpp console is refused rather than
  silently converted.
- **Flat guards, four arms.** `CYRIUS_TARGET_{AGNOS,LINUX,MACOS,WIN}` — cycc predefines exactly one via
  an if/else ladder (`cyrius/src/main.cyr:1085-1099`) whose own comment states agnos is *not*
  `CYRIUS_TARGET_LINUX`. Nested `#ifdef` is used nowhere in this ecosystem and is not introduced here.
- **macOS and Windows keep the -1 stub, as a decision.** Those platforms have their own desktops and
  bhumi is not competing with them. The stub is deliberate, not an omission.
- **No new stdlib dependencies.** `sys_open`/`sys_read`/`sys_close` come from `syscalls`, already
  declared. `lib/mmap.cyr` is deliberately unused (see `MAP_SHARED` above), so `[deps].stdlib` is
  unchanged and "flat domain module, no stdlib includes" stays honest.

## Consequences

- **Positive** — a sovereign compositor renders to a real Linux screen with no libdrm, no logind, no
  X, no Wayland and no root: `/dev/fb0` via the `video` group is sufficient. Every layer above the seam
  gains a second substrate that can be developed and demonstrated without hardware or an emulator.
- **Positive** — the pure/impure split from ADR 0001 pays again. Sysfs parsing, struct packing, format
  derivation and blit clipping are all pure functions with unit tests, so CI (which has no framebuffer)
  covers everything except the syscalls themselves.
- **Negative** — `bhumi_output_present` now has a **visible side effect on Linux**. The unit suite used
  to assert `present(fb) == -1` on a host; that assertion painted an 8×8 block on the operator's screen
  the moment this arm landed. It has been removed — the device path belongs to a program you run on
  purpose (`programs/fbdev-probe.cyr`), not to `cyrius test`. Treat any future test that calls `present`
  as a bug.
- **Negative** — fbdev is a legacy shim over DRM and is single-buffered: there is no page flip, so a
  slow frame can tear. Acceptable for bring-up, and the reason DRM/KMS remains on the roadmap.
- **Neutral** — only works from a bare VT. On a box already running a desktop, `/dev/fb0` *is* that
  desktop's framebuffer.

## Verification

`programs/fbdev-probe.cyr`, run on archaemenid-class hardware 2026-08-12:

```
fbdev-probe: geometry 2560x1440 pitch 10240 bpp 32 pxfmt 1
fbdev-probe: sentinel pixels seen through an independent fd: 64 of 64 (mismatched 0)
fbdev-probe: PASS -- scanout reaches /dev/fb0, corner restored
```

⛔ **The oracle is external on purpose.** Reading the sentinel back through bhumi's own mapping would
pass even under `MAP_PRIVATE` — the write and the read would hit the same private page. The probe
re-opens `/dev/fb0` on a **separate fd** and `pread`s, which shares no page tables with the mapping and
therefore observes what the device actually holds.

## Alternatives considered

- **DRM/KMS dumb buffers first** — deferred, not rejected. The right long-term answer, but it requires
  growing the seam (buffer lifetime, page flip, connector enumeration, mode selection) before a single
  pixel appears. fbdev reaches the same screen through the interface that already exists.
- **A nested Wayland client** — rejected. It is the only path that produces pixels inside an existing
  desktop session, and puka already has a libwayland-free client to borrow from, but a sovereign
  compositor rendering into another compositor's window is a different product, not a backend.
- **mabda** — rejected, and rejected *again*: aethersafha's `roadmap.md` records that the "GPU goes
  through mabda" claim survived in three live documents at once and cost more than one session of
  wasted direction. mabda's GPU surface rides Linux's driver stack; this is a scanout seam.
- **Keep Linux as a logic-only substrate** — this is the status quo being reversed, recorded here so the
  reversal is legible: it was coherent, it was documented on both sides of the seam, and the operator
  changed it.
