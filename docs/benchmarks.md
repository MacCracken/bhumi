# bhumi Benchmarks

Microbenchmarks for the hot paths of each subsystem. Reproduce with:

```sh
cyrius bench tests/bhumi.bcyr
```

**Machine:** AMD Ryzen 7 5800H · **Toolchain:** cyrius 6.3.34 · **Target:** x86_64
Linux host (the pure userland paths; the agnos kernel seams are no-ops here).
**Method:** `bench_new` → `bench_batch_start` → tight loop → `bench_batch_stop` →
`bench_report`. Sub-µs ops run 1,000,000 iterations to amortize the
`clock_gettime` start/stop overhead; full-frame ops run 30 iterations. Numbers
are single-run averages — indicative, not statistically rigorous.

## Results (v0.6.0)

| Operation | Avg | Notes |
|---|---:|---|
| `noop` (clock baseline) | 2 ns | measurement floor |
| `seat_can` (capability gate check) | 9 ns | active + device bit + expiry |
| `fb_set` (bounds-checked pixel write) | 13 ns | 2 bounds branches + `store32` |
| `kbd_diff` (HID report decode) | 59 ns | one 8-byte report → events |
| `fb_clear` 1280×720 (full-frame fill) | 975 µs | direct `store32` loop, ~1 ns/px |
| `pattern_xor` 1280×720 | 18.6 ms | per-pixel via `bhumi_fb_set` |
| `pattern_bars` 1280×720 | 21.1 ms | per-pixel via `bhumi_fb_set` |

## Interpretation

- **The gate is free.** `seat_can` at 9 ns is negligible — routing every device op
  through the capability gate costs nothing at frame rates. Same for the input
  decode: a 59 ns `kbd_diff` per report is immaterial against human key rates.
- **Fills are memory-bound and fast.** `fb_clear` moves a 720p XRGB frame
  (~3.7 MB) in ~975 µs — roughly 1 ns/pixel, i.e. memory bandwidth. A compositor
  clearing/copying full frames has ample headroom (~1000 fps of pure fill).
- **The pattern generators are diagnostics, not a hot path.** `pattern_bars` /
  `pattern_xor` at ~20 ms are dominated by the per-pixel `bhumi_fb_set` (13 ns ×
  921 k px ≈ 12 ms) plus the per-pixel bar/xor computation. That is ~20× slower
  than the direct `fb_clear` loop, by design: the patterns use the *safe*
  bounds-checked path because they run once at bring-up. A per-frame renderer
  would write pixels through a direct fill (like `fb_clear`), not `fb_set`.

## Caveat

These measure bhumi's userland compute. The agnos device paths (`blit`#39 scanout,
`kbscan`#42 drain) are kernel syscalls not exercised on the host; their cost is
the kernel's and is measured on agnos hardware/QEMU, not here.
