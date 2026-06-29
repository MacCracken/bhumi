# bhumi — Roadmap

> Milestone plan through v1.0. State lives in [`state.md`](state.md);
> this file is the sequencing — what ships, in what order, against
> what dependency gates.

## v1.0 criteria

_Define before tagging v0.1.0:_

- [ ] Public API frozen — every exported symbol documented and tested
- [ ] Test coverage adequate for the surface area
- [ ] Benchmarks captured in `docs/benchmarks.md`
- [ ] At least one downstream consumer green
- [ ] CHANGELOG complete from v0.1.0 onward
- [ ] Security audit pass (`docs/audit/YYYY-MM-DD-audit.md`)

## Milestones

### M0 — Scaffold (v0.1.0) — ✅ shipped 2026-06-29

- `cyrius init` scaffold landed
- Doc-tree per [first-party-documentation.md](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md)
- ADRs / architecture notes / guides / examples folders ready

### M1 — Output: agnodrm scanout (v0.2.0)

`src/output.cyr` — enumerate the display via **agnodrm** (DRM/KMS device model),
acquire a scanout target, and push a framebuffer to the screen through the agnos
kernel `blit#39` path. Acceptance: a known test pattern reaches a real (or QEMU)
framebuffer end-to-end. **Dep gate**: agnodrm DRM/KMS surface; kernel `blit#39`
(landed).

### M2 — Input: kernel event source (v0.3.0)

`src/input.cyr` — drain keyboard/pointer events from the kernel `hid_poll` path
into a normalized event stream the compositor consumes. Acceptance: keystrokes
and pointer motion surface as bhumi input events. **Dep gate**: kernel input
syscall surface (the xHCI `hid_poll` path).

### M3 — Seat: native device-access gate (v0.4.0)

`src/seat.cyr` — a sovereign seat/session model (one seat = a focus + its input
devices + its scanout) gated by **sigil/kavach capabilities**, *not* logind /
`/etc/passwd`. Acceptance: device access is capability-gated; seat hand-off works.

### M4 — Assembled backend (v0.5.0)

`src/backend.cyr` — fold output + input + seat into the single backend handle
**aethersafha** instantiates. Acceptance: aethersafha drives a frame loop against
bhumi (first downstream consumer green). Removes the `bhumi_scaffold_ok` sentinel.

## Out of scope (for v1.0)

- **X11 / XWayland.** AGNOS has no native X11 clients; the compat layer is dead weight.
- **Foreign-app surface hosting.** That is [`mehman`](https://github.com/MacCracken/mehman) (the swallow-stage compat backend).
- **The Wayland protocol / client lifecycle.** Stays in aethersafha; bhumi is the platform below it.
- **Multi-GPU / multi-seat orchestration** beyond a single seat — deferred past v1.0.
- **Non-AGNOS targets.** bhumi is agnos-kernel-facing by design (it bootstraps on Linux only insofar as agnodrm does).
