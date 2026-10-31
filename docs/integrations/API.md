# API and Bridge Contracts

## 1. No remote API in the MVP

Cam-Anime has **no backend, no REST API, no GraphQL, and no network calls**. The release build has no `INTERNET` permission. This file documents the **internal** Flutter ↔ native bridge, which is the only "API" the MVP has.

## 2. Bridge conventions

- Channel names: `MethodChannel("camanime/engine")`, `EventChannel("camanime/engine/events")`.
- Method name format: `<domain>.<action>`.
- Arguments and results are maps of primitives. Pixel buffers are **never** transferred; only small payloads (thumbnail bytes ≤ 256 KB) are allowed.
- Errors: `PlatformException(code, message, details)` with the codes below. Dart maps them to a sealed `EngineError`.
- Versioning: `engine.getInfo` returns `apiVersion` (integer). Dart checks it at start; a mismatch shows a developer error screen. Incompatible changes increment it.
- iOS parity: the same names/codes will be implemented on iOS later.
- Status: **contract draft; implemented in M1 (subset) and M2-M7 (rest).**

## 3. Methods

| Method | Args | Result | Milestone |
|---|---|---|---|
| `engine.getInfo` | – | `{apiVersion:int, engineVersion:string, androidSdk:int}` | M1 |
| `permissions.getStatus` | `{permission:'camera'\|'microphone'}` | `{granted:bool, shouldShowRationale:bool}` | M1 |
| `permissions.request` | `{permission}` | `{granted:bool, shouldShowRationale:bool}` | M1 |
| `permissions.openAppSettings` | – | `{}` | M1 |
| `camera.start` | `{lens:'back'\|'front', qualityTier:'q720p30'\|'q720p24'\|'q480p30'}` | `{textureId:int, previewWidth:int, previewHeight:int, capabilities:Capabilities}` | M1 |
| `camera.stop` | – | `{}` | M1 |
| `camera.switchLens` | `{lens}` | `{textureId, previewWidth, previewHeight, capabilities}` | M1 |
| `camera.setZoomRatio` | `{ratio:double}` | `{ratio:double}` (clamped) | M1 |
| `camera.setTorch` | `{enabled:bool}` | `{enabled:bool}` | M1 |
| `camera.setFlashMode` | `{mode:'off'\|'on'\|'auto'}` | `{mode}` | M5 |
| `render.setStyle` | `{styleId:string}` | `{styleId}` | M4 |
| `capture.takePhoto` | `{}` | `MediaResult` | M5 |
| `recording.start` | `{audio:bool}` | `{}` | M6 |
| `recording.stop` | – | `MediaResult` | M6 |
| `media.exists` | `{uris:[string]}` | `{exists:[bool]}` | M7 |
| `media.delete` | `{uris:[string]}` | `{deleted:[bool]}` | M7 |
| `media.loadThumbnail` | `{uri, size:int}` | `{bytes:Uint8List}` | M7 |
| `media.share` | `{uri}` | `{}` | M7 |
| `media.freeSpaceBytes` | – | `{bytes:int}` | M5 |
| `perf.setQualityCap` | `{cap:'auto'\|'720p'\|'480p'}` | `{}` | M8 |
| `perf.setMode` | `{mode:'auto'\|'saving'}` | `{}` | M8 |

Types:

```
Capabilities { lenses:['back','front'], zoomMin:double, zoomMax:double, hasFlash:bool, hasTorch:bool }
MediaResult  { uri:string, displayName:string, mimeType:string, width:int, height:int,
               sizeBytes:int, createdAtMs:int, durationMs:int?, hasAudio:bool }
```

## 4. Events (EventChannel)

All events: `{type:string, tsMs:int, ...}`.

| `type` | Payload | Notes |
|---|---|---|
| `cameraState` | `{state:'idle'\|'starting'\|'running'\|'switching'\|'error'}` | |
| `firstFrame` | `{}` | Hides the loading placeholder |
| `stats` | `{fps:double, renderMsP50:double, inferMsP50:double, maskAgeMs:double}` | ≤ 1 Hz, only when debug overlay on |
| `qualityTier` | `{tier:'q720p30'\|'q720p24'\|'q480p30'\|'effect_off', reason:'thermal'\|'slow'\|'user'\|'recovered'}` | |
| `thermal` | `{status:'none'\|'light'\|'moderate'\|'severe'\|'critical'\|'emergency'\|'shutdown'}` | From PowerManager (API 29+) |
| `subject` | `{present:bool}` | For the "step into frame" hint |
| `recordingState` | `{state:'idle'\|'recording'\|'finalizing', elapsedMs:int, hasAudio:bool}` | 1 Hz while recording |
| `interrupted` | `{reason:'background'\|'storage'\|'error'}` | Recording ended by the system |
| `error` | `{code:string, message:string, recoverable:bool}` | |

## 5. Error codes

`PERMISSION_DENIED` · `CAMERA_IN_USE` · `CAMERA_UNAVAILABLE` · `CAMERA_ERROR` · `GL_INIT_FAILED` · `MODEL_LOAD_FAILED` · `MODEL_INTEGRITY_FAILED` · `ENCODER_FAILED` · `AUDIO_UNAVAILABLE` · `STORAGE_LOW` · `STORAGE_WRITE_FAILED` · `INVALID_ARGUMENT` · `NOT_STARTED` · `ALREADY_RECORDING` · `UNSUPPORTED` · `INTERNAL`

## 6. Future API boundaries (not implemented, not funded)

Identified so that the MVP does not block them; there is **no fictional backend** in this repository.

| Possible future boundary | Design rule now |
|---|---|
| Optional cloud backup of media | Dart `MediaRepository` stays the only gateway to media metadata; a backup service would be a separate Dart interface, off by default, user-initiated |
| Optional account | No user identifiers in the DB now; add later as separate tables |
| Remote model/style catalog | Models are addressed by `id@version` and verified by SHA-256 already ([MODEL_ASSET_MANAGEMENT](../models/MODEL_ASSET_MANAGEMENT.md)), so a downloader can be added without changing the engine |
| Entitlements / paid features | Feature flags behind an interface; none exist in the MVP |

Any such feature must remain optional: the app must work fully when it is absent or unreachable.
