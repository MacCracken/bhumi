# 0002 — The seat is a lean capability enforcer, not a crypto verifier

**Status**: Accepted
**Date**: 2026-07-02

## Context

M3 gives bhumi a sovereign seat/session model: exactly one seat is foreground,
and only it may drive the framebuffer (M1) and keyboard (M2) — the sovereign
answer to the Linux DRM-master / logind / VT-switch problem, without logind,
uids, `/etc/passwd`, or a setuid helper. The roadmap says access is gated by
"sigil/kavach capabilities."

Reviewing the ecosystem for the mechanism turned up three facts:

- **No kernel seat/capability/session/sandbox syscall exists** — unlike output
  (`fbinfo`/`blit`) and input (`kbscan`), there is no kernel ABI to wrap. The gate
  is a userland construct bhumi originates.
- **`sigil` is the crypto/trust boundary** — Ed25519/ECDSA/ML-DSA verify plus
  revocation lists — but it is ~25,000 lines and drags in `bayan` + a `sakshi`
  git dep. **`kavach` is the sandbox** (process confinement, `agnosys[security]`),
  with no callable library API here.
- **No "capability token" or "seat" type exists** anywhere — bhumi defines it.

So the real choice is *where the trust boundary sits*: does bhumi cryptographically
verify capabilities itself, or enforce capabilities that a trusted authority
issues?

## Decision

bhumi is a **lean capability enforcer**, not a crypto verifier. It defines the
`BhumiCap` (subject, device bitmask, expiry, issuer) and `BhumiSeat` (id, active,
held cap) types and gates every device op — `bhumi_seat_present`,
`bhumi_seat_poll` — on `bhumi_seat_can`: the seat must be **active** AND hold a
capability that **grants that device** and **has not expired**. A background seat
is always denied. Foreground arbitration (`bhumi_seat_handoff`) enforces exactly
one active seat.

Cryptographic **issuance and verification stay in sigil** (the auth issuer);
**process confinement stays in kavach** (the sandbox). bhumi trusts a capability
handed to it by the seat authority. Each `BhumiCap` carries a reserved signature
slot (`BHUMI_CAP_SIG`, unused today) so a later bite can add an optional sigil
Ed25519 verify hook without changing this model.

## Consequences

- **Positive** — bhumi stays lean (no 25k-line crypto dependency in the platform
  layer) and honors AGNOS's one-component-one-job split: sigil signs, kavach
  sandboxes, bhumi gates. The gate is pure and fully host-testable (active +
  scope + expiry) independent of any device or kernel.
- **Negative** — bhumi does not independently authenticate a capability's origin;
  it trusts the issuer. A forged capability handed straight to bhumi (bypassing
  sigil/kavach) would be honored. The `BHUMI_CAP_SIG` hook is where defense-in-
  depth verification would land if that threat model changes.
- **Neutral** — the capability-token wire format and the issuance path (how a
  seat obtains a genuine capability from sigil/kavach) are defined elsewhere; M4
  (the assembled backend aethersafha instantiates) will exercise the seam.

## Alternatives considered

- **Full crypto verifier (add sigil, Ed25519-verify each capability)** — rejected:
  ~40× bhumi's size, drags a whole crypto stack into the platform layer, and
  duplicates sigil's role as THE crypto boundary. Defense-in-depth that a
  platform backend should not own.
- **Model-first, gate later** — rejected as the *starting* point: the gate *is*
  M3's substance ("device access is capability-gated"), so building the seat
  mechanics without committing to the enforcement model would invite rework.
