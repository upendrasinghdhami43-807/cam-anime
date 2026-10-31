# Integrations

How each external component plugs into the system. Library APIs referenced here are **[REF]**: confirm against the linked official documentation when implementing; do not copy signatures from this file.

## 1. Flutter ↔ Android native

- **Registration:** `CamAnimePlugin` implements `FlutterPlugin`, `ActivityAware`, `MethodChannel.MethodCallHandler`; it receives `FlutterPluginBinding` (for `textureRegistry`, `binaryMessenger`) and `ActivityPluginBinding` (activity, `addRequestPermissionsResultListener` or ActivityResult registry, lifecycle). Host `MainActivity` extends `FlutterFragmentActivity` or `FlutterActivity` so a `LifecycleOwner` is available (choice confirmed in M1; CameraX needs a `LifecycleOwner`). See [Flutter plugin docs](https://docs.flutter.dev/packages-and-plugins/developing-packages).
- **Channels:** `MethodChannel("camanime/engine")` for commands, `EventChannel("camanime/engine/events")` for state. Codec: `StandardMethodCodec` (maps, lists, byte arrays for thumbnails only). Contract: [API](API.md).
- **Threading:** handlers return quickly on main, dispatch to engine executors, reply on main (`Result` is thread-affine to the platform thread in practice; post back via `Handler(Looper.getMainLooper())`).
- **Texture:** `TextureRegistry` → `SurfaceProducer` (or `SurfaceTextureEntry`) → `Surface` → EGL window surface. Dart side uses `Texture(textureId:)`.
- **Dart client:** `features/camera/data/camera_engine_client.dart` is the only Dart file that knows channel names.

## 2. CameraX

- Dependencies (names, versions **[REF]**): `androidx.camera:camera-core`, `camera-camera2`, `camera-lifecycle`, and `camera-video` only if ADR-006 picks Path A. Versions are set once in the Gradle version catalog; confirm the current stable release on the [CameraX release page](https://developer.android.com/jetpack/androidx/releases/camera). A secondary source reports 1.6.x as stable; unverified.
- Use cases and binding: [CAMERA_PIPELINE §2](../architecture/CAMERA_PIPELINE.md#2-camerax-use-cases).
- Camera permission precedes binding. Camera errors map to API error codes.
- Reference docs: [CameraX overview](https://developer.android.com/media/camera/camerax), [Preview](https://developer.android.com/media/camera/camerax/preview), [Analyze images](https://developer.android.com/media/camera/camerax/analyze), [Video capture](https://developer.android.com/media/camera/camerax/video-capture).

## 3. ML runtime integration

- Wrapper interface `Segmenter { fun start(); fun submit(frame: AnalysisFrame); fun latestMask(): MaskFrame?; fun close() }` in `vision/`, with one implementation per runtime evaluated in S2; only the winner stays in the repo.
- Models loaded from `assets/models/` after SHA-256 verification ([MODEL_ASSET_MANAGEMENT](../models/MODEL_ASSET_MANAGEMENT.md)).
- Runtime libraries are added only after ADR-005; their `.so` ABI filters limited to `arm64-v8a` (plus `armeabi-v7a` only if the audience needs it) to cap APK size [REC; OQ-05].
- Docs: [MediaPipe Solutions](https://ai.google.dev/edge/mediapipe), [LiteRT](https://ai.google.dev/edge/litert), [ONNX Runtime](https://onnxruntime.ai/docs/).

## 4. OpenCV

Not integrated in the MVP (ADR-004). If approved later: build via CMake `find_package`/prebuilt Android SDK, link only needed modules statically, run on the inference/IO thread, never on the GL thread. License: Apache-2.0 for OpenCV ≥ 4.5 [REF, confirm].

## 5. Shaders / OpenGL ES

- Loaded from assets, compiled on the GL thread at engine start, cached program objects.
- Interop: `SurfaceTexture(textureId)` bound to `GL_TEXTURE_EXTERNAL_OES`; encoder via `MediaCodec.createInputSurface()` + EGL window surface with `EGL_RECORDABLE_ANDROID`; Flutter via the producer `Surface`.
- Docs: [OpenGL ES on Android](https://developer.android.com/develop/ui/views/graphics/opengl), [EGL extensions](https://registry.khronos.org/EGL/).

## 6. Media / storage

- `MediaStore.Images|Video.Media.EXTERNAL_CONTENT_URI` inserts with `RELATIVE_PATH`, `IS_PENDING`; `ContentResolver.loadThumbnail` for thumbnails; share via `Intent.ACTION_SEND` with a content URI (`FLAG_GRANT_READ_URI_PERMISSION`).
- Docs: [Android media storage](https://developer.android.com/training/data-storage/shared/media).

## 7. Flutter packages (initial list; no others without approval)

| Package | Purpose | License / status |
|---|---|---|
| `flutter_riverpod` | State management | MIT [REF] |
| `go_router` | Navigation | BSD-3 [REF], Flutter team |
| `drift`, `sqlite3_flutter_libs`, `drift_dev`, `build_runner` | Database | MIT [REF] |
| `path_provider` | DB location | BSD [REF], Flutter team |
| `video_player` | Video playback in gallery | BSD [REF], Flutter team (uses ExoPlayer/Media3 on Android) |
| `share_plus` or native share via bridge | Sharing | Prefer native bridge call to avoid a package; decide at M7 |
| `flutter_lints` (dev) | Lints | BSD [REF] |

Package versions are never hand-written in docs; `pubspec.lock` is the source of truth. License confirmation is task T-M1-02 in the implementation plan.

## 8. Optional future integrations (not in MVP, none may be required offline)

Cloud backup (user-initiated, end-to-end encrypted), account system, remote model catalog, paid features via Google Play Billing, crash reporting with explicit consent. Each needs a privacy review and an ADR first.
