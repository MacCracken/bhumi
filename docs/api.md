# bhumi Public API — frozen at v0.7.0

The stable public surface: **70 functions + the semantic constants** below.
Consume the library via the single-file bundle
(`[deps.bhumi] modules = ["dist/bhumi.cyr"]`). This contract is machine-enforced
against the bundle by [`scripts/api-surface.sh`](../scripts/api-surface.sh) in CI —
removing or renaming any symbol here fails the build. Internal `_bhumi_*`
functions and record-layout offset constants (`BHUMI_FB_WIDTH`, `BHUMI_CAP_SUBJECT`,
`BHUMI_BE_SEAT`, …) are **not** part of the contract; use the accessors.

All functions return / take `i64`; pointers are `i64` addresses.

## Output — framebuffer (`output.cyr`)

- `bhumi_xrgb(r, g, b)` — pack 8-bit channels into an XRGB8888 pixel.
- `bhumi_fb_new(width, height)` — allocate a `BhumiFb` (XRGB8888); `0` on bad dims / OOM.
- `bhumi_fb_{width,height,pitch,format,bpp,pixels,size}(fb)` — geometry accessors.
- `bhumi_fb_set(fb, x, y, pixel)` — write a pixel; `0` ok, `-1` out of bounds (never clamped).
- `bhumi_fb_get(fb, x, y)` — read a pixel; the value, or `-1` out of bounds.
- `bhumi_fb_clear(fb, pixel)` — fill the whole framebuffer; `0`.

## Output — scanout (`scanout.cyr`)

- `bhumi_output_query(info)` — fill a ≥ `BHUMI_FBINFO_SIZE` buffer with display geometry; bytes / `-1`.
- `bhumi_fbinfo_{width,height,pitch,bpp,pxformat,present}(info)` — parse the geometry struct.
- `bhumi_output_format_ok(info)` — `1` if the framebuffer's byte order matches `BhumiFb` (BGRX).
- `bhumi_output_present(fb)` — scan the framebuffer out at the origin; `0` / `-1` (or `-1` off-agnos).

## Patterns (`pattern.cyr`)

- `bhumi_pattern_bars(fb)` / `bhumi_pattern_xor(fb)` — draw a bring-up test pattern; `0` / `-1`.
- `bhumi_bar_color(i)` / `bhumi_bar_index(width, x)` / `bhumi_xor_value(x, y)` — pattern helpers.

## Input — decode (`input.cyr`)

- `bhumi_key_event(pressed, usage)` — pack a normalized key event (USB HID usage).
- `bhumi_key_pressed(ev)` / `bhumi_key_usage(ev)` — accessors.
- `bhumi_kbd_diff(prev, cur, out, max_ev)` — diff two 8-byte HID boot reports into events; count.

## Input — drain (`kbscan.cyr`)

- `bhumi_input_init(prev)` — zero the caller's held HID report.
- `bhumi_input_process(prev, raw, n, out, max_ev)` — decode drained HID reports; count.
- `bhumi_scancode_process(raw, n, out, max_ev)` — decode drained AT/XT Set-1 scancodes (agnos `kbscan`#42) into the same normalized key events; count. Pure/host-testable.
- `bhumi_input_poll(prev, out, max_ev)` — drain (`kbscan`#42 on agnos) + decode; count (`0` off-agnos). On agnos it decodes Set-1 scancodes; on the host it decodes HID reports.

## Seat — capability (`seat.cyr`)

- `bhumi_cap_new(subject, devices, expiry, issuer)` — mint a `BhumiCap`; `0` on OOM.
- `bhumi_cap_{subject,devices,expiry,issuer}(c)` — accessors.
- `bhumi_cap_grants(c, device, now)` — `1` if `c` grants `device` at `now` (unexpired).
- `bhumi_cap_signed_bytes(c, out)` — the 32-byte canonical signed message; count.
- `bhumi_cap_set_sig(c, sig)` / `bhumi_cap_sig(c)` — the signature-blob slot.
- `bhumi_cap_verify(c, verify_fn, pubkey)` — `1` if a caller-supplied Ed25519 verifier accepts the cap's provenance (opt-in; bhumi embeds no crypto).

## Seat — the gate (`seat.cyr`)

- `bhumi_seat_new(id)` — create a background seat; `0` on OOM.
- `bhumi_seat_{id,active,cap}(s)` — accessors.
- `bhumi_seat_grant(s, cap)` — hand the seat a capability.
- `bhumi_seat_can(s, device, now)` — `1` iff active **and** its capability grants `device`.
- `bhumi_seat_activate(s)` / `bhumi_seat_deactivate(s)` — foreground control.
- `bhumi_seat_handoff(from, to)` — pairwise hand-off.
- `bhumi_seat_present(s, fb, now)` / `bhumi_seat_poll(s, prev, out, max_ev, now)` — gated device ops; the raw op result, or `BHUMI_SEAT_DENIED`.

## Seat — manager (`seat.cyr`)

- `bhumi_seatmgr_new()` — a registry guaranteeing one active seat; `0` on OOM.
- `bhumi_seatmgr_{count,active}(m)` — accessors.
- `bhumi_seatmgr_add(m, seat)` — register; `0` / `-1` if full (`BHUMI_SEATMGR_MAX`).
- `bhumi_seatmgr_has(m, seat)` — membership.
- `bhumi_seatmgr_switch(m, seat)` — make `seat` foreground (deactivating the old); `0` / `-1` unregistered.
- `bhumi_seatmgr_release(m)` — drop the foreground (no active seat).

## Backend — assembled (`backend.cyr`)

- `bhumi_backend_open(cap, width, height)` — the single handle: primary fb + input + owned foreground seat; `0` on null cap / bad dims / OOM.
- `bhumi_backend_{seat,fb,width,height}(be)` — accessors.
- `bhumi_backend_poll(be, out, max_ev, now)` / `bhumi_backend_present(be, now)` — gated frame-loop ops.
- `bhumi_backend_activate(be)` / `bhumi_backend_deactivate(be)` — VT-switch foreground control.

## Public constants

- **Pixel format:** `BHUMI_FMT_XRGB8888`, `BHUMI_FB_MAX_DIM`.
- **Scanout:** `BHUMI_FBINFO_SIZE`, `BHUMI_PXFMT_RGBX`, `BHUMI_PXFMT_BGRX`.
- **Patterns:** `BHUMI_BARS_N`.
- **Input:** `BHUMI_HID_REPORT_SIZE`, `BHUMI_HID_KEY_MIN`, and the usage-page-0x07
  landmarks `BHUMI_HID_{A,ENTER,ESC,BSPACE,TAB,SPACE,RIGHT,LEFT,DOWN,UP}` +
  modifiers `BHUMI_HID_{LCTRL,LSHIFT,LALT,LGUI,RCTRL,RSHIFT,RALT,RGUI}`.
- **Seat:** `BHUMI_DEV_OUTPUT`, `BHUMI_DEV_INPUT`, `BHUMI_SEAT_DENIED`,
  `BHUMI_CAP_MSG_SIZE`, `BHUMI_SEATMGR_MAX`.

## Stability

Frozen at **v0.7.0**. Additions (new symbols) are backward-compatible and append
to this list; removals or renames are breaking changes gated by CI. Deferred
surface not yet present: pointer input (awaits a kernel pointer syscall).
