# Testing Strategy

A camera app is not done because it builds. Each layer below proves something the layers under it cannot. Acceptance criteria (`AC-*`) come from the [PRD](../product/PRD.md).

## 1. Layers

| Layer | Tooling | Proves | Runs |
|---|---|---|---|
| Dart unit | `flutter test` | Pure logic: settings mapping, permission-state resolver, style catalog, error mapping, DB repository (in-memory Drift), quality-tier mapping | Every change |
| Flutter widget | `flutter test` with fake `CameraEngineClient` | Screens and states: S-03 variants, S-04 states (starting/running/error/recording), gallery empty/loaded, settings persistence | Every change |
| Kotlin JVM unit | JUnit via `./gradlew :camanime_engine:testDebugUnitTest` | Mask smoothing, subject-presence hysteresis, quality controller, timestamp rebasing, error code mapping, model manifest/checksum logic, MediaStore naming | Every change |
| Native instrumented | AndroidX Test on the phone (`connectedDebugAndroidTest`) | EGL init/teardown, offscreen shader golden tests, MediaStore write/delete, codec availability probe, model loading | Per milestone on device |
| Flutter integration | `integration_test` on the phone | Launch → permission → preview → capture → gallery happy path (permissions via `adb shell pm grant` in test setup) | M7+ |
| Manual device checklists | Phone + `adb` | Camera lifecycle, orientation, A/V sync, thermal, battery, real lighting | Per milestone |

## 2. Mapping from acceptance criteria to tests

| AC | Automated | Manual / device |
|---|---|---|
| AC-01, AC-02 | Widget tests of S-03 variants; Kotlin unit of status mapping | Fresh install run; deny, deny permanently (Settings), grant in Settings |
| AC-03 | – | 20 flips; `adb shell dumpsys media.camera` after |
| AC-04 | Kotlin unit of transform math (rotation/mirror matrix) | Visual: person with text/arrow; front and rear; rotate device |
| AC-05 | Instrumented lifecycle stress (start/stop ×50) | `adb shell` loop: `input keyevent HOME` / relaunch ×50; check logcat for leaks, `dumpsys media.camera`, `dumpsys SurfaceFlinger --list` |
| AC-06 | Instrumented golden: mask=0 → output==input; mask=1 → toon | Visual 5-10 clips |
| AC-07 | Widget test: style rail dispatch; instrumented: switch every style 100× without GL errors | Visual |
| AC-08 | Instrumented MediaStore write test | Capture; check system gallery and in-app gallery |
| AC-09 | Kotlin unit: timestamp rebasing | Clap-and-flash sync test (§4), `ffprobe` of output: codecs, duration, rotation |
| AC-10 | – | 10-min recording; no ANR; valid file |
| AC-11 | `scripts/verify_no_internet.sh` (M8) on merged manifest | Airplane-mode walkthrough |
| AC-12 | – | Benchmark procedure (PERFORMANCE §3) |
| AC-13 | Kotlin unit: quality controller transitions/hysteresis | Thermal override via `adb` (§5) |
| AC-14 | Drift repository tests; widget tests | Delete via system gallery then open in-app gallery |
| AC-15 | Kotlin unit: free-space guard | Fill storage with a dummy file; try to record |
| AC-16 | Widget semantics tests (`meetsGuideline`) | TalkBack walkthrough |
| AC-17 | Instrumented: no mic request before record | Fresh install flow |
| AC-18 | – | Background app during preview; `dumpsys media.camera` shows no client |

## 3. Camera lifecycle and permission tests (device)

Checklist (each run recorded with date/commit/device):
- [ ] Cold start with permission granted → preview ≤ 2.5 s
- [ ] Cold start without permission → rationale → grant → preview
- [ ] Deny → Try again → Deny permanently → Open settings → grant → resume shows preview
- [ ] Revoke permission in Settings while app backgrounded → resume shows rationale (no crash)
- [ ] Press Home, wait 10 s, return (×20)
- [ ] Open another camera app while backgrounded; return → recover or show `CAMERA_IN_USE`
- [ ] Screen lock/unlock during preview and during recording
- [ ] Incoming-call simulation during recording (`adb shell am start`/call from another phone)
- [ ] Rotate device (portrait lock) — UI stable
- [ ] Force-stop and relaunch

## 4. Audio/video synchronization test

1. Record 60 s of a screen showing a stopwatch-flash/click sequence or perform a hand-clap with a visible hand motion, in front of the phone, 3 repetitions at 0, 20, 40 s.
2. Pull the file (`adb pull`), inspect with `ffprobe`/`ffmpeg` (Linux: `sudo apt install ffmpeg` only for testing) and frame-step in a player; compute offset between the visible impact frame and the audio waveform peak (e.g., Audacity or `ffmpeg -af astats`).
3. Pass: |offset| ≤ 80 ms at every repetition and no cumulative drift (> 40 ms change across 60 s). Result recorded in `docs/performance/results/`.

## 5. Performance, thermal, and soak tests

Method in [PERFORMANCE](../performance/PERFORMANCE.md). Thermal: `adb shell dumpsys thermalservice` to read status; `adb shell cmd thermalservice override-status <n>` to simulate (command names [REF]; confirm on the device's Android version; reset with `reset`). Soak: 30 min preview + three 10-min recordings; watch memory (`adb shell dumpsys meminfo <package>`), FPS, tier changes, logcat for `ANR`/`FATAL`.

## 6. Offline operation tests

- [ ] Airplane mode on, Wi-Fi/data off: full flow (permission → style → photo → video → gallery → delete).
- [ ] `aapt2 dump permissions app-release.apk` has no `INTERNET`; merged manifest checked.
- [ ] `adb shell dumpsys netstats`/`nethogs`-style check shows no app traffic during use [REF; optional].

## 7. Rendering tests

Offscreen EGL tests (androidTest): fixed input PNG + fixed mask PNG → each style → compare with golden PNGs (SSIM or per-pixel tolerance, see RENDERING_ENGINE §7). Invariants: mask 0/1, Original, mirror correctness (asymmetric test image). Goldens regenerate only via an explicit script and review.

## 8. Regression testing

Every bug fix adds a test at the lowest layer possible or an entry in the manual checklist. Before each milestone close and release: run all automated suites + the device lifecycle checklist + the relevant AC subset. Keep a short `docs/development/` run log in PROJECT_STATUS (date, commit, device, results).

## 9. Physical device testing rules

- Reference device = the owner's phone (OQ-01); add at least one Tier B phone before M9 if obtainable.
- Test builds: debug for functionality, **profile** for performance, release for final acceptance.
- Record device model, Android version, build mode, commit, battery %, charging state, ambient temperature estimate, screen brightness.

## 10. MVP acceptance suite

M9 runs AC-01…AC-18 with this document's checklists. Result table lives in `docs/project/READY_FOR_DEVELOPMENT.md` → later `PROJECT_STATUS.md`. A build that passes only the automated layers is **not** release-ready.
