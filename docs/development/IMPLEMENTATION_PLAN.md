# Implementation Plan

Rules: one task at a time, in dependency order; a task is **Done** only when its verification step was executed and recorded in [PROJECT_STATUS](../project/PROJECT_STATUS.md). Tasks needing the phone are marked 📱 (REQUIRES REAL-DEVICE VALIDATION).

Legend: `T-<milestone>-<nn>`; *Deps* = prerequisite task IDs; *Out* = expected output; *Verify* = how completion is proven.

---

## M0 — Environment ready

| ID | Task | Deps | Out | Verify |
|---|---|---|---|---|
| T-M0-01 | Run `scripts/check_env.sh`, share output | – | Baseline | Output reviewed |
| T-M0-02 | Install JDK 17 (if missing) | 01 | `/usr/lib/jvm/java-17-*` | `ls /usr/lib/jvm` |
| T-M0-03 | Install Flutter stable | 01 | `flutter` on PATH | `flutter --version` (record in STATUS) |
| T-M0-04 | Install Android Studio + SDK (platform-tools, platform, build-tools, cmdline-tools), set `ANDROID_HOME`, accept licenses | 03 | SDK dir | `flutter doctor -v` Android toolchain ✓ |
| T-M0-05 | `flutter config --jdk-dir` JDK 17 | 02,03 | Config | `flutter config` shows jdk-dir |
| T-M0-06 📱 | Enable USB debugging, connect phone, authorize | 04 | Device listed | `adb devices -l` shows `device`; `flutter devices` lists it |
| T-M0-07 | Record device facts, close OQ-01 | 06 | STATUS updated | Fields filled from `adb shell getprop` |
| T-M0-08 | `git init`, first commit of docs (user approval) | – | Git history | `git log` |

**Done when:** `flutter doctor -v` clean for Android and the phone is listed.

---

## M1 — First coding milestone: native CameraX prototype inside Flutter 📱

Goal: the Flutter app launches on the phone, native CameraX shows the rear preview in a Flutter `Texture`, permission and lifecycle work, front switching works if supported. **No cartoon processing, no GL, no ML.**

Checklist in required order:

| ID | Task | Deps | Out | Verify |
|---|---|---|---|---|
| T-M1-01 | Create the Flutter app: `flutter create --org <OQ-02 org> --platforms android apps/mobile` (name `camanime`), commit untouched baseline | M0 | Project skeleton | `flutter analyze` passes; `flutter test` passes |
| T-M1-02 | Set `minSdk 29`, portrait lock, `flutter_lints`; add **only** `flutter_riverpod` and `go_router`; record versions and licenses in TECHNICAL_DECISIONS | 01 | pubspec/lock | `flutter pub get`; `flutter run` shows default app on phone 📱 |
| T-M1-03 | Create Android library module `camanime_engine` (Kotlin) in `apps/mobile/android`, include it in `settings.gradle`, depend from `:app` | 02 | Empty module builds | `flutter build apk --debug` passes |
| T-M1-04 | Add CameraX dependencies (`camera-core`, `camera-camera2`, `camera-lifecycle`; versions from the official release page, in the version catalog) to the engine module | 03 | Gradle sync OK | `flutter build apk --debug` |
| T-M1-05 | Implement `CamAnimePlugin` (`FlutterPlugin`, `ActivityAware`), register from `MainActivity`; implement `engine.getInfo` | 03 | Channel round trip | Dart prints engine info; unit test of channel handler |
| T-M1-06 | Switch `MainActivity` to a `LifecycleOwner`-capable base class if needed; declare `CAMERA` in the manifest (no `INTERNET` in `main`, only debug/profile) | 05 | Manifest | `aapt2 dump permissions` on the debug APK shows CAMERA |
| T-M1-07 | Native permission handling: `permissions.getStatus/request/openAppSettings`; Dart `PermissionsClient` + S-03 screen with the 4 variants | 06 | S-03 works | 📱 AC-01, AC-02 manual checks; widget tests for the 4 variants with a fake client |
| T-M1-08 | Create a `SurfaceProducer`/texture entry via `TextureRegistry`; return `textureId`, `previewSize` | 05 | Texture registered | Debug log of ids; unit-testable parts tested |
| T-M1-09 | Bind CameraX `Preview` (rear) with a `SurfaceProvider` that supplies the texture's surface; `camera.start/stop`; events `cameraState`, `firstFrame` | 04,07,08 | Preview frames flow | 📱 Rear preview visible in Flutter `Texture` |
| T-M1-10 | Orientation/mirroring for M1 using `TransformationInfo` rotation → Dart `RotatedBox`; verify portrait upright on rear | 09 | Upright preview | 📱 AC-04 (rear) |
| T-M1-11 | Lifecycle: stop/unbind on pause, restart on resume, release on detach; error events for camera errors | 09 | No leaks | 📱 background/resume ×20; `adb shell dumpsys media.camera` shows no stale client; AC-05 (partial) |
| T-M1-12 | `camera.switchLens` + front preview with mirroring; hide switch if no front camera | 10,11 | Switching | 📱 AC-03 (×20 switches), AC-04 (front) |
| T-M1-13 | `camera.setZoomRatio`, `camera.setTorch` and minimal Dart controls (pinch zoom, torch toggle) | 12 | Controls | 📱 zoom/torch visibly work; clamped values |
| T-M1-14 | Minimal camera screen (S-04 skeleton: preview + flip + torch + zoom pill; no styles/gallery) and error panel for `CAMERA_IN_USE`/`CAMERA_ERROR` | 13 | UI | 📱 Manual run; widget test with fake engine client |
| T-M1-15 | Run the M1 acceptance checklist (below); update STATUS, CHANGELOG; capture logcat of one clean run | 14 | Report | All boxes ticked on the phone |

**M1 acceptance criteria (all must be true on the physical phone):**
1. `flutter run` launches the app on the phone.
2. Native CameraX initializes (logcat shows engine start; no exceptions).
3. First launch shows the rationale screen, then the system permission dialog; granting shows the preview within 2 s.
4. Denied and permanently-denied states offer working recovery (retry / app settings, auto re-check on resume).
5. Rear preview appears in the Flutter `Texture`, upright, correct aspect ratio.
6. Front camera switch works (if the device has one), mirrored, ≥ 20 switches without a leak or crash.
7. Backgrounding/resuming 20 times keeps the preview working; `dumpsys media.camera` shows the camera released while backgrounded.
8. Pinch zoom and torch work within device capabilities.
9. No pixel data crosses the platform channel (code review of bridge + Dart client).
10. `flutter analyze`, `flutter test`, and `./gradlew :camanime_engine:testDebugUnitTest` pass.
11. No cartoon/ML/GL code exists yet.

Only after M1 passes do we start S1-S3 and M2+.

---

## Spikes (time-boxed, outputs are decisions + measurements in `research/<id>/`)

| ID | Question | Deps | Out | Decision |
|---|---|---|---|---|
| S3 | Flutter `SurfaceProducer` vs `SurfaceTexture` entry; EGL window surface on it; frame pacing; resize | M1 | Prototype + notes | Confirms ADR-002 API; informs M2 |
| S2 | MediaPipe Tasks vs LiteRT for person segmentation on the phone (time, size, quality) | M1 | Table of measurements | ADR-005 |
| S1 | Recording path A (CameraEffect) vs B (custom) with GL render | M2 | Measurements + sync test | ADR-006 |

(S3 precedes M2; S2 precedes M3; S1 precedes M6 and needs the M2 render pipeline.)

---

## M2 — GL passthrough pipeline 📱
| ID | Task | Deps | Verify |
|---|---|---|---|
| T-M2-01 | EGL core + render thread (single owner), OES texture input | S3 | Unit tests for state machine (JVM); 📱 frame drawn |
| T-M2-02 | Replace M1's direct-to-Flutter surface with camera→GL→Flutter surface; upright/mirror in shader; remove Dart rotation | 01 | 📱 AC-04 in portrait, front/rear |
| T-M2-03 | Bounded frame handoff, frame stats (fps, render ms), debug overlay event | 02 | 📱 ≥ 30 FPS passthrough at 720p recorded in profile mode |
| T-M2-04 | Lifecycle teardown/recreate of GL + producer | 02 | 📱 AC-05 ×50 |

## M3 — Segmentation 📱
| T-M3-01 | `Segmenter` interface + chosen runtime + model loading with checksum | S2 | Unit tests (checksum, load failure) |
| T-M3-02 | ImageAnalysis → model input (reused buffers), mask smoothing, `subject` event | 01,M2 | JVM tests for smoothing/coverage logic |
| T-M3-03 | Mask upload + debug overlay view (mask tinted over preview) | 02 | 📱 Visual check on 5-10 test clips; measure mask lag (OQ-10) |

## M4 — Cartoon shader + compositing 📱
| T-M4-01 | P1-P3 passes, style JSON loader, 4 styles + Original | M3 | Offscreen golden tests (androidTest) pass; 📱 visual |
| T-M4-02 | `render.setStyle` bridge + Dart style rail (S-06 inline) | 01 | AC-07 📱; widget tests |
| T-M4-03 | Staleness fade, no-subject behavior | 01 | AC-06 invariants test |

## M5 — Photo 📱
| T-M5-01 | Capture read-back (PBO), JPEG encode, MediaStore write, free-space check | M4 | AC-08 📱 |
| T-M5-02 | Drift DB (`media_items`, `app_settings`), repository, insert on capture | 01 | DB unit tests incl. migration test scaffold |
| T-M5-03 | Flash/torch for photo; shutter UI, feedback | 01 | 📱 |

## M6 — Video 📱
| T-M6-01 | Implement the S1-chosen path; audio permission flow | S1,M4 | AC-09, AC-17 📱 |
| T-M6-02 | Timer, recording state events, interruptions finalize | 01 | AC-10 📱 (10 min), AC-15 |
| T-M6-03 | A/V sync measurement (clap/flash test) recorded | 01 | ≤ 80 ms or fix |

## M7 — Gallery, settings, onboarding, polish 📱
| T-M7-01 | Gallery grid/viewer/share/delete + reconciliation (S-10, S-11) | M5,M6 | AC-14 📱 + widget tests |
| T-M7-02 | Settings (S-12), About & Privacy + delete all (S-13), onboarding (S-02), splash | 01 | Widget tests; AC-16 TalkBack 📱 |
| T-M7-03 | Accessibility pass, volume-key shutter, large-font check | 02 | NFR-09 checklist |

## M8 — Performance & thermal 📱
| T-M8-01 | Thermal listener, quality controller with hysteresis, StatusChip | M6 | AC-13 📱 (thermal simulation: `adb shell cmd thermalservice override-status` [REF]) |
| T-M8-02 | Benchmark procedure run, results saved in `docs/performance/results/` | 01 | AC-12 recorded |
| T-M8-03 | `scripts/verify_no_internet.sh` + CI-like local check script (analyze/test/build) | – | AC-11 |

## M9 — MVP hardening and release candidate 📱
| T-M9-01 | Full acceptance run AC-01…AC-18 on the reference device; Tier B device run | M7,M8 | Signed-off checklist |
| T-M9-02 | License/notice review of all libraries and models; privacy text final | – | Report in docs/project |
| T-M9-03 | Release build, signing setup, size check (NFR-05) | 01 | `flutter build apk --release` + `appbundle`; APK inspected |
| T-M9-04 | Fix P0/P1 bugs, update CHANGELOG, tag v1.0.0 (user approval) | 01-03 | Tag |

## Completion checklist for any task

- [ ] Acceptance/verification step executed (not assumed)
- [ ] Formatters/analyzers clean
- [ ] Tests added/updated and passing
- [ ] Build compiles (`flutter build apk --debug`)
- [ ] Device-only items listed as pending validation if the phone was not used
- [ ] Docs, STATUS, CHANGELOG updated
