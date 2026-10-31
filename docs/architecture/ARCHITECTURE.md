# Architecture

Status: draft v0.1. Decisions and rationale: [TECHNICAL_DECISIONS](TECHNICAL_DECISIONS.md). Evidence labels: see [README](../../README.md#evidence-labels-used-in-the-docs).

## 1. System overview

Cam-Anime is a single-process Android app. There is no server. A Flutter UI controls a native Kotlin engine that owns the camera, GPU rendering, ML inference and recording. Pixels stay inside the native process and GPU memory; Flutter only displays an externally produced texture.

```
┌──────────────────────────── Flutter (Dart, main isolate) ────────────────────────────┐
│ presentation (widgets, Riverpod controllers) → domain (entities, use cases)          │
│                     → data (Drift DB, bridge clients)                                │
└───────────────┬───────────────────────────────────▲───────────────────────────────────┘
        MethodChannel (commands)            EventChannel (state/events)       Texture(id)
┌───────────────▼───────────────────────────────────┴───────────────┬──────────────────┐
│ Kotlin engine  `camanime_engine` (Android library module)         │ Flutter engine   │
│  bridge  ─ CamAnimePlugin, channel handlers, permission handling  │ SurfaceProducer  │
│  camera  ─ CameraX controller (Preview, ImageAnalysis, lifecycle) │      ▲           │
│  vision  ─ segmenter wrapper, mask smoothing, subject presence    │      │ EGL       │
│  gl      ─ EGL context, render thread, shaders, compositor ───────┼──────┘ window    │
│  record  ─ video/audio encoders + muxer (path chosen in S1)       │   surface        │
│  media   ─ MediaStore writer, photo encoder                       │                  │
│  perf    ─ thermal, frame-time monitor, quality controller        │                  │
└───────────────────────────────────────────────────────────────────┴──────────────────┘
```

## 2. Technology stack (MVP)

| Layer | Choice | Notes |
|---|---|---|
| UI | Flutter (stable channel), Dart, Material 3 | Version pinned by the installed SDK at M0 and recorded in PROJECT_STATUS |
| State / DI | Riverpod | ADR-009 |
| Navigation | go_router | ADR-009 |
| Local DB | SQLite via Drift (+ `sqlite3_flutter_libs`) | ADR-007, [DATABASE](../data/DATABASE.md) |
| Native language | Kotlin | |
| Camera | AndroidX CameraX | [REF] current stable line 1.6.x per a secondary source; confirm at M1 with the [official release page](https://developer.android.com/jetpack/androidx/releases/camera) |
| Rendering | OpenGL ES 3.0 via EGL, GLSL ES 3.00 shaders | ADR-003 |
| ML | Undecided between MediaPipe Tasks Vision and LiteRT direct (spike S2) | ADR-005 |
| Recording | CameraX `CameraEffect` + `VideoCapture` or custom MediaCodec/MediaMuxer (spike S1) | ADR-006 |
| C++ / OpenCV | **Not in MVP** | ADR-004 |
| Build | Gradle + AGP via Flutter tooling, JDK 17 | ADR-016 |
| iOS (future) | Swift, AVFoundation, Metal | §8 |

## 3. Module boundaries and ownership

| Module | Location | Owns | Must not |
|---|---|---|---|
| Flutter app | `apps/mobile/lib` | UI, navigation, state, DB access, bridge clients | Touch pixels; call CameraX; hold camera state beyond mirrored UI state |
| Bridge | `camanime_engine/.../bridge` | Channel parsing, error mapping, permission/activity glue | Contain business logic; block the main thread |
| Camera | `.../camera` | CameraX binding, lens/zoom/flash, lifecycle, frame handoff | Know about Flutter or DB |
| Vision | `.../vision` | Model loading/verification, inference, mask post-processing | Know about rendering API beyond a mask texture/ByteBuffer contract |
| GL / Render | `.../gl` | EGL, shaders, framebuffers, compositing, output surfaces | Run inference; touch Android UI |
| Record | `.../record` | Encoder lifecycle, audio capture, muxing, A/V timestamps | Decide styles |
| Media | `.../media` | JPEG encoding, MediaStore insert/delete, free-space checks | Hold DB handles (DB lives in Dart) |
| Perf | `.../perf` | Thermal listener, frame stats, quality tier decisions | Change visuals directly (emits tier events) |

Dependency direction inside the engine: `bridge → camera, gl, vision, record, media, perf`; `camera → gl, vision` (frame handoff via interfaces); `record → gl` (encoder surface target). No cycles.

## 4. Layer responsibilities (Flutter)

- **presentation:** widgets and Riverpod notifiers; no platform calls directly.
- **domain:** plain Dart entities (`MediaItem`, `CartoonStyle`, `CameraState`), repository interfaces, use cases only where logic exists (don't create empty pass-through use cases).
- **data:** Drift DAO, repository implementations, `CameraEngineClient` (wraps channels).
- **core:** logging, result/error types, theme tokens, shared widgets, constants.

## 5. Data flow

1. UI calls `CameraEngineClient.start(...)` → MethodChannel → engine creates a `SurfaceProducer`/texture → returns `textureId`, `previewSize`.
2. Engine binds CameraX use cases. Camera frames go to the GL render thread's input surface (zero CPU copy); a downscaled analysis stream feeds the segmenter.
3. The render thread draws the composite into: the Flutter texture surface (always), the encoder surface (while recording), a capture request (on shutter).
4. Engine emits events (state, FPS, thermal tier, errors) on the EventChannel; Dart updates UI.
5. On capture the engine writes the file to MediaStore and returns `{uri, width, height, durationMs?, ...}`; Dart inserts the metadata row in SQLite.

Full details and thread model: [CAMERA_PIPELINE](CAMERA_PIPELINE.md).

## 6. Platform integration

- **Flutter host app** (`apps/mobile/android/app`): thin; registers the `camanime_engine` plugin via a manual `FlutterPlugin` registration in `MainActivity.configureFlutterEngine` (or `GeneratedPluginRegistrant` if packaged as a local plugin; decided in M1, ADR-014 revisit).
- **Permissions:** native. `AndroidManifest` declares `CAMERA`, `RECORD_AUDIO`; no `INTERNET`; storage permissions are not needed with MediaStore on API 29+ for the app's own media.
- **Lifecycle:** the engine observes the activity lifecycle (`ActivityAware` + `LifecycleOwner` bridge); camera is released in `onPause`/`ON_STOP` and reacquired on resume.
- **Details:** [INTEGRATIONS](../integrations/INTEGRATIONS.md), [API](../integrations/API.md).

## 7. Cross-cutting concerns

- **Threading:** main (UI/bridge only), camera executor, GL render thread, inference thread, encoder threads, IO executor.
- **Error model:** engine errors carry stable string codes (`API.md`); Dart maps them to UI states.
- **Observability:** local-only logging (`Log`/Dart logger), in-app debug overlay (FPS, tier, mask latency) behind a developer setting. No network telemetry.
- **Security/privacy:** [SECURITY](../security/SECURITY.md), [STORAGE_AND_PRIVACY](../data/STORAGE_AND_PRIVACY.md).

## 8. Future iOS architecture (not built in the MVP)

- Same Flutter app and Dart code. New native module in `apps/mobile/ios` (Swift): `AVCaptureSession` → `CVPixelBuffer` → Metal render → `FlutterTexture` (pixel-buffer texture) / `CVMetalTextureCache`; `AVAssetWriter` for recording; Vision/Core ML or MediaPipe/LiteRT for segmentation (decision deferred).
- The Dart-side bridge contract ([API](../integrations/API.md)) is platform-neutral by design: the same method/event names and error codes.
- Shaders are re-implemented in Metal from the algorithm specification in [RENDERING_ENGINE](RENDERING_ENGINE.md); style parameter JSON is shared.
- Shared C++ is optional and only if an ADR proves a need (ADR-004).
- Constraint on Android work: don't leak Android concepts into the Dart API (e.g., no `SurfaceTexture` names), and keep style/model manifests platform-neutral.
