# bhumi

> भूमि — *ground / earth*. The ground the AGNOS desktop stands on.

**Sovereign userland platform backend for the AGNOS compositor** ([aethersafha](https://github.com/MacCracken/aethersafha)), written in [Cyrius](https://github.com/MacCracken/cyrius) with zero external dependencies.

## What it is

bhumi is the userland layer between the compositor and the **agnos kernel** — the sovereign replacement for the Linux compositor-backend trio (DRM/KMS + libinput + logind). It gives the compositor three things and nothing more:

| Linux backend | bhumi module | agnos surface |
|---|---|---|
| DRM/KMS (`libdrm`) | `src/output.cyr` | agnodrm → kernel `blit#39` / framebuffer |
| libinput / evdev | `src/input.cyr` | kernel `hid_poll` input events |
| logind session/seat | `src/seat.cyr` | native seat (sigil/kavach capability gate, **not** logind) |

## What it is NOT

- **Not XWayland.** AGNOS has zero native X11 clients — the X.Org compat layer solves a problem the sovereign stack does not have.
- **Not a client-compat bridge.** Hosting *foreign* app surfaces is [`mehman`](https://github.com/MacCracken/mehman)'s job (the swallow-stage compat backend, post-MVP).
- **Not the Wayland protocol / client lifecycle.** That is aethersafha proper. bhumi is the *platform* below it.

bhumi is the **first** of the two compositor backends to build — aethersafha sits directly on it.

## Build

```sh
cyrius deps                                        # resolve stdlib deps
cyrius build programs/smoke.cyr build/bhumi-smoke   # compile-link smoke
cyrius distlib                                     # produce dist/bhumi.cyr
cyrius test                                        # run tests/*.tcyr
```

## License

GPL-3.0-only
