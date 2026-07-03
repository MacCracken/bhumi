#!/bin/sh
# api-surface.sh — enforce bhumi's FROZEN public API against the dist bundle.
#
# Every symbol below is part of the public contract frozen at v0.7.0. Removing or
# renaming one is a breaking change and MUST fail CI. Adding a new public symbol
# is allowed (append it here). Run:  sh scripts/api-surface.sh [dist/bhumi.cyr]
#
# The list is hardcoded on purpose: deriving it from src/ would let a deletion
# silently drop from both sides and pass. See docs/api.md for the reference.

set -eu
DIST="${1:-dist/bhumi.cyr}"
[ -f "$DIST" ] || { echo "api-surface: $DIST not found — run 'cyrius distlib'"; exit 1; }

# --- 70 public functions ---
FNS="
bhumi_xrgb bhumi_fb_new bhumi_fb_width bhumi_fb_height bhumi_fb_pitch
bhumi_fb_format bhumi_fb_bpp bhumi_fb_pixels bhumi_fb_size bhumi_fb_set
bhumi_fb_get bhumi_fb_clear
bhumi_fbinfo_width bhumi_fbinfo_height bhumi_fbinfo_pitch bhumi_fbinfo_bpp
bhumi_fbinfo_pxformat bhumi_fbinfo_present bhumi_output_query
bhumi_output_format_ok bhumi_output_present
bhumi_bar_color bhumi_bar_index bhumi_pattern_bars bhumi_xor_value
bhumi_pattern_xor
bhumi_key_event bhumi_key_pressed bhumi_key_usage bhumi_kbd_diff
bhumi_input_init bhumi_input_process bhumi_input_poll
bhumi_cap_new bhumi_cap_subject bhumi_cap_devices bhumi_cap_expiry
bhumi_cap_issuer bhumi_cap_grants bhumi_cap_signed_bytes bhumi_cap_set_sig
bhumi_cap_sig bhumi_cap_verify
bhumi_seat_new bhumi_seat_id bhumi_seat_active bhumi_seat_cap bhumi_seat_grant
bhumi_seat_can bhumi_seat_activate bhumi_seat_deactivate bhumi_seat_handoff
bhumi_seat_present bhumi_seat_poll
bhumi_seatmgr_new bhumi_seatmgr_count bhumi_seatmgr_active bhumi_seatmgr_add
bhumi_seatmgr_has bhumi_seatmgr_switch bhumi_seatmgr_release
bhumi_backend_open bhumi_backend_seat bhumi_backend_fb bhumi_backend_width
bhumi_backend_height bhumi_backend_poll bhumi_backend_present
bhumi_backend_activate bhumi_backend_deactivate
"

# --- public semantic constants (offset/layout enums are internal) ---
CONSTS="
BHUMI_FMT_XRGB8888 BHUMI_FB_MAX_DIM BHUMI_FBINFO_SIZE BHUMI_PXFMT_RGBX
BHUMI_PXFMT_BGRX BHUMI_BARS_N BHUMI_HID_REPORT_SIZE BHUMI_HID_KEY_MIN
BHUMI_HID_A BHUMI_HID_ESC BHUMI_HID_LCTRL BHUMI_DEV_OUTPUT BHUMI_DEV_INPUT
BHUMI_SEAT_DENIED BHUMI_CAP_MSG_SIZE BHUMI_SEATMGR_MAX
"

miss=0
nfn=0
for f in $FNS; do
    nfn=$((nfn + 1))
    grep -qE "^fn ${f}\(" "$DIST" || { echo "MISSING fn:    $f"; miss=1; }
done
ncon=0
for c in $CONSTS; do
    ncon=$((ncon + 1))
    grep -qE "\b${c} *=" "$DIST" || { echo "MISSING const: $c"; miss=1; }
done

if [ "$miss" -ne 0 ]; then
    echo "api-surface: FAIL — the frozen public API changed (see docs/api.md)"
    exit 1
fi
echo "api-surface: OK — ${nfn} functions + ${ncon} constants present in $DIST"
