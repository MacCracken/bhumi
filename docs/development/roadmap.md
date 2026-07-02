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

### M1 — Output: framebuffer scanout (v0.2.0) — ✅ shipped 2026-07-02

`src/output.cyr` (software `BhumiFb`), `src/scanout.cyr` (kernel handoff), and
`src/pattern.cyr` (test patterns). The display is queried and a framebuffer
pushed to the screen through the agnos kernel **`fbinfo`#38 / `blit`#39** path
(the syscalls landed agnos 1.51.0 — there is no separate agnodrm mode surface
for a single fixed-mode scanout; the syscalls are the surface). See
[ADR 0001](../adr/0001-scanout-via-agnos-fbinfo-blit.md).

Code-complete against the real ABI and verified cross-target: the `--agnos`
build emits `syscall` #38/#39, 86 host assertions pass, and the fuzz harness
holds. **Acceptance** — a known test pattern reaching a real (or QEMU)
framebuffer end-to-end — is carried by `programs/scanout-demo.cyr`; running it
on agnos hardware/QEMU for the visual confirmation is a manual downstream step
(not reachable from host CI, matching the sibling agnos-lib precedent).

### M2 — Input: kernel event source (v0.3.0) — ✅ shipped 2026-07-02

`src/input.cyr` — drain keyboard events from the kernel and normalize them into
the event stream the compositor consumes. Acceptance: keystrokes surface as
bhumi key events.

**ABI (reviewed 2026-07-02):** keyboards attach over **USB/xHCI HID** — agnos has
no PS/2 and never will. bhumi models input as **USB HID usage codes** (page 0x07)
and derives press/release by diffing successive HID keyboard reports (reports are
state-based). The kernel drains the xHCI USB-HID ring to ring-3 via **`kbscan`#42**.
There is **no mouse/pointer/HID-pointer syscall** in any snapshot (surface tops
at agnos 1.51.0), so **pointer motion is deferred** until the kernel lands one —
not stubbed with a fabricated ABI. v0.3.0 is keyboard-only.

Shipped: the HID-decode half (normalized key-event model + `bhumi_kbd_diff`), the
`kbscan`#42 drain seam (`bhumi_input_poll` / `_process` / `_init`, cross-target —
the `--agnos` binary emits `syscall` #42), the `input-demo` acceptance artifact,
and fuzz coverage of the report decoder. Deferred: **pointer input**, once the
agnos kernel lands a pointer/HID-pointer syscall.

### M3 — Seat: native device-access gate (v0.4.0) — in progress

`src/seat.cyr` — a sovereign seat/session model (one seat = a focus + its input
device + its scanout) gated by **sigil/kavach capabilities**, *not* logind /
`/etc/passwd`. Acceptance: device access is capability-gated; seat hand-off works.

**Trust boundary (decided 2026-07-02, [ADR 0002](../adr/0002-seat-lean-capability-enforcer.md)):**
there is no kernel cap ABI; sigil (~25k lines) is the crypto issuer and kavach the
sandbox. bhumi is the **lean enforcer** — it gates device access on possession of
a valid capability (active seat + device scope + expiry) and trusts sigil/kavach
for issuance/verification, carrying a reserved signature slot for a future verify
hook.

Landed: the seat + capability model and the gate (`bhumi_seat_can`,
`bhumi_seat_present` / `_poll`, `bhumi_seat_handoff`). Next to close v0.4.0: a
seat-manager over N seats (single-active invariant), a hand-off demo, fuzz over
the gate, and the version cut.

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
