# bhumi — Claude Code Instructions

> **Core rule**: this file is **preferences, process, and procedures** —
> durable rules that change rarely. Volatile state (current version,
> module line counts, supported backends, test counts, dep-gap status,
> consumers) lives in [`docs/development/state.md`](docs/development/state.md).
> Do not inline state here.

## Project Identity

**bhumi** — sovereign userland platform backend for the AGNOS compositor (भूमि, *ground / earth*)

- **Type**: Library
- **License**: GPL-3.0-only
- **Language**: Cyrius (toolchain pinned in `cyrius.cyml [package].cyrius`)
- **Version**: `VERSION` at the project root is the source of truth — do not inline the number here
- **Standards**: [First-Party Standards](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-standards.md) · [First-Party Documentation](https://github.com/MacCracken/agnosticos/blob/main/docs/development/applications/first-party-documentation.md)

## Goal

bhumi owns the **platform backend** for [aethersafha](https://github.com/MacCracken/aethersafha) — the userland layer that gives the compositor pixels-out (agnodrm → kernel `blit#39`), events-in (kernel `hid_poll`), and a native seat (sigil/kavach gate). It is the sovereign replacement for the Linux DRM/KMS + libinput + logind backend trio. It is **not** XWayland and **not** a client-compat bridge — hosting foreign app surfaces is [`mehman`](https://github.com/MacCracken/mehman)'s job. bhumi is *platform*, below the protocol; the Wayland client lifecycle stays in aethersafha.

## Current State

> Volatile state lives in [`docs/development/state.md`](docs/development/state.md) —
> current version, surface area, in-flight work, consumers, dep gaps.
> Refreshed every release.

This file (`CLAUDE.md`) is durable rules.

## Scaffolding

Project was scaffolded with `cyrius init` (greenfield) or `cyrius port` (Rust → Cyrius migration). **Do not manually create project structure** — use the tools. If a tool is missing something, fix the tool.

## Quick Start

```sh
cyrius deps                          # resolve sibling deps
cyrius build programs/smoke.cyr build/bhumi-smoke
cyrius test                          # run [build].test + tests/*.tcyr
```

## Key Principles

- **Correctness over cleverness** — if it's wrong, the bugs own you
- Test after every change, not after the feature is "done"
- ONE change at a time — never bundle unrelated changes
- Research before implementation — check vidya / existing patterns
- Build with `cyrius build`, not raw `cat file | cc5` — the manifest auto-resolves deps and prepends includes
- Source files only need project includes — stdlib / external deps auto-resolve from `cyrius.cyml`
- Every buffer declaration is a contract: `var buf[N]` = N **bytes**, not N entries
- `&&` / `||` short-circuit; mixed expressions require explicit parens

## Rules (Hard Constraints)

- **Do not commit or push** — the user handles all git operations
- **Never use `gh` CLI** — use `curl` to the GitHub API if needed
- Do not skip tests before claiming changes work
- Do not use `sys_system()` with unsanitized input — command injection
- Do not trust external data (file / network / args) without validation
- Do not modify `lib/` files (vendored stdlib / dep symlinks)
- Do not hardcode toolchain versions in CI YAML — `cyrius = "X.Y.Z"` in `cyrius.cyml` is the source of truth

## Documentation

- [`docs/adr/`](docs/adr/) — Architecture Decision Records (*why X over Y?*)
- [`docs/architecture/`](docs/architecture/) — Non-obvious constraints (*what's true about the code?*)
- [`docs/guides/`](docs/guides/) — Task-oriented how-tos
- [`docs/examples/`](docs/examples/) — Runnable examples
- [`docs/development/state.md`](docs/development/state.md) — Live state snapshot
- [`docs/development/roadmap.md`](docs/development/roadmap.md) — Milestones through v1.0

## Process

1. **Work phase** — features, roadmap items, bug fixes
2. **Build check** — `cyrius build`
3. **Test + benchmark additions** for new code
4. **Internal review** — performance, memory, correctness, edge cases
5. **Documentation** — update CHANGELOG, `docs/development/state.md`, any ADR the change earned
6. **Version sync** — `VERSION`, `cyrius.cyml`, CHANGELOG header

