# Performance

All numbers in this file are **targets or estimates [EST]**, not measurements. A number becomes a fact only when a result file under `docs/performance/results/` (created in M2+) records device, build mode, commit and method. Nothing has been measured yet.

## 1. Targets

| Metric | Target | Source |
|---|---|---|
| Preview resolution | 1280x720 (portrait 720x1280) | PRD |
| Frame rate | 24-30 FPS; AC-12 passes at median ≥ 24 | PRD NFR-01 |
| Latency (move → pixels) | ≤ 150 ms goal | NFR-02 |
| Frame budget @30 FPS | 33.3 ms total; render path ≤ 8 ms GPU time [EST] | engineering |
| Inference | Async, decoupled; target ≤ 33 ms per run on the reference device (so mask updates ≥ 30/s) or run every 2nd frame (≥ 15 Hz mask) [EST] | S2 decides |
| Mask age at render | p95 ≤ 100 ms [EST] | M3 |
| Cold start | ≤ 2.5 s | NFR-03 |
| Memory (PSS) | ≤ 400 MB [EST]; native + graphics counted | NFR-04 |
| APK size | ≤ 80 MB incl. models [EST] | NFR-05 |
| CPU load | Main thread idle; total app CPU < ~40 % of one big core during preview [EST] | |
| Battery | To be measured in M8; no promise | NFR-10 |

## 2. Device tiers (provisional)

| Tier | Definition [EST] | Expected behavior |
|---|---|---|
| A | Recent flagship/high-end SoC (≈ 2021+) | 720p30 with effect |
| B | Mid-range (≈ 2019+) | 720p24 or 480p30 with effect; AC-12 relaxed to ≥ 20 FPS with fallback |
| C | Low-end / old | Effect may be unavailable; plain preview + capture; not an MVP acceptance target |

The reference device (OQ-01) is classified into a tier at M0 from its SoC and measured results.

## 3. Benchmark methodology

Controls: profile build; same commit; phone ≥ 60 % battery, **not charging** for power runs and charging for FPS-only runs (recorded); screen brightness 50 %; airplane mode; other apps closed; room 20-25 °C; phone not in a case; cool start (idle ≥ 10 min); fixed test scene: one person standing 2 m away indoors with typical lighting (≥ 200 lux [EST]), moderate motion script (wave arms, turn); front and rear tested separately.

Procedure per configuration (tier × lens × style):
1. Warm-up 60 s (discarded).
2. Measure 5 minutes: engine `stats` events at 1 Hz (fps, renderMsP50, inferMsP50, maskAgeMs) logged to a local file via the debug overlay; plus
   - `adb shell dumpsys meminfo <pkg>` at 0/2.5/5 min,
   - `adb shell dumpsys SurfaceFlinger --latency` or Perfetto trace for frame pacing [REF],
   - thermal status samples every 10 s via `dumpsys thermalservice` [REF],
   - Android Studio Profiler or Perfetto for CPU/GPU when diagnosing.
3. Record dropped-frame count and max gap (> 100 ms stalls).
4. Repeat 3 runs, report median and worst run.

Soak: 30-min preview + recording at 720p: record FPS vs time, tier switches, temperature progression.

Battery: 30-min runs from the same starting percentage with fixed brightness; compare `dumpsys batterystats` / `dumpsys battery` deltas against a baseline of the stock camera app for 30 min [REF]; report relative, not absolute, numbers.

Result file template (`docs/performance/results/YYYY-MM-DD_<device>_<commit>.md`): device, Android version, build mode, commit, config, table of metrics (median/p95), notes, pass/fail vs targets.

## 4. Adaptive quality policy

Tiers (matches API `qualityTier`): `q720p30` → `q720p24` → `q480p30` → `effect_off` (plain preview, still capturable).

| Trigger | Action |
|---|---|
| Thermal status ≥ MODERATE [REF: `PowerManager` constants `THERMAL_STATUS_*`] | Down one tier |
| Thermal ≥ SEVERE | `q480p30` and inference rate halved |
| Thermal ≥ CRITICAL | `effect_off`; if recording, stop gracefully and save with a message |
| p50 frame time > 40 ms over 3 s while thermal none | Down one tier |
| p50 frame time < 28 ms for 30 s and thermal ≤ LIGHT | Try up one tier (max once per minute) |
| Battery saver on | Start at `q720p24` [REC] |
| User quality cap 480p/720p | Upper bound |

Hysteresis prevents oscillation; each change emits `qualityTier` and shows StatusChip. During recording the encoder size is fixed; only the render input scales [OPEN, S1].

## 5. Memory budget (EST)

| Component | Budget |
|---|---|
| Flutter engine + UI | ~100-150 MB |
| GL textures/FBOs (720p RGBA ×4-5 ≈ 3.7 MB each) | ~20 MB |
| Model + runtime | model size ×2 + runtime overhead (unknown until S2) |
| Encoder buffers | ~30-50 MB |
| Headroom | rest of 400 MB |

## 6. CPU/GPU budgets

Main thread: bridge only. GL thread: ≤ 8 ms/frame. Inference: own thread; must not starve the camera executor. Avoid GPU delegate contention with rendering unless measured better (OPEN, S2). Encoder: hardware codec; negligible CPU.

## 7. Performance regression rule

After M4, every milestone repeats the baseline benchmark; > 10 % FPS drop or > 15 % memory increase vs the previous result requires investigation before merge [EST thresholds].
