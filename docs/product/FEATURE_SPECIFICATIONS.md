# Feature Specifications

Each feature lists inputs, outputs, logic, behavior and acceptance criteria. IDs match the [PRD](PRD.md). Bridge names refer to [API](../integrations/API.md).

---

## F-01 Camera permission (FR-01, FR-11, FR-15) — AC-01, AC-02, AC-17

- **Input:** user entering S-04; user pressing record.
- **Output:** permission state `granted | denied | blocked`; camera start or recovery UI.
- **Logic:** Permissions are handled natively (Kotlin `ActivityResult` API), exposed via `permissions.*` bridge calls. "Blocked" = not granted and `shouldShowRequestPermissionRationale == false` **after** at least one request has been made (tracked in a settings key `perm.camera.requested`), because Android returns `false` both before the first request and after "don't ask again".
- **Behavior:** Camera asked on S-04 entry through S-03. Microphone asked only at first recording press. Resuming from system settings re-checks permission.
- **Acceptance:** AC-01, AC-02, AC-17.

## F-02 Live preview (FR-02, FR-03, FR-04, FR-05) — AC-03, AC-04, AC-05

- **Input:** `startCamera(lens, qualityTier)`, `switchLens`, `setZoomRatio`, `setFlashMode`/`setTorch`, lifecycle.
- **Output:** `textureId` and `previewSize` (upright, post-rotation), events `firstFrame`, `state`, `error`, `capabilities` (lenses, zoom range, flash available).
- **Logic:** CameraX use cases bound to the activity lifecycle. Target 1280x720, rotation-aware. Front preview mirrored. Zoom via `CameraControl.setZoomRatio` clamped to `ZoomState` range. Flash only when `CameraInfo.hasFlashUnit()`.
- **Behavior:** see [USER_FLOWS §4](USER_FLOWS.md#4-camera-workflows). Camera released on pause; no background access.
- **Acceptance:** AC-03, AC-04, AC-05.

## F-03 Human foreground segmentation (FR-06) — AC-06, AC-12

- **Input:** downscaled analysis frames (≤ 256x256 model input [EST]) from ImageAnalysis, latest-only.
- **Output:** per-frame foreground mask texture (single channel, 0-1) with a frame timestamp; `subjectPresent` boolean (mask coverage > threshold for N frames).
- **Logic:** model selected in spike S2 ([AI_AND_COMPUTER_VISION](../architecture/AI_AND_COMPUTER_VISION.md)); EMA temporal smoothing on the mask; runs on its own thread; if inference is slower than the camera, intermediate frames are dropped and the last mask is reused, with a staleness limit (mask older than 250 ms [EST] → fade the effect out rather than show a wrong silhouette).
- **Behavior:** single primary subject; with several people the model's output is used as-is (no per-person guarantees in MVP).
- **Acceptance:** AC-06, AC-12.

## F-04 Mode A cartoon stylization and compositing (FR-07, FR-08) — AC-06, AC-07

- **Input:** camera image, mask, style parameters, front/back orientation.
- **Output:** composited RGBA frame to preview, encoder and photo targets.
- **Logic:** per [RENDERING_ENGINE](../architecture/RENDERING_ENGINE.md): foreground = stylized(camera), background = camera, blended by mask with feathering. "Original" skips the shader chain but keeps the pipeline.
- **Styles (MVP):** Cel Pop, Ink Comic, Soft Pastel, Noir Sketch (+ Original). Parameters are data (JSON in assets), not hardcoded per shader.
- **Behavior:** style switch applies on the next frame; styles locked while recording.
- **Acceptance:** AC-06, AC-07.

## F-05 Photo capture (FR-09) — AC-08, AC-15

- **Input:** shutter press, current style, flash mode.
- **Output:** JPEG (quality 92 [REC]) in `Pictures/Cam-Anime/` via MediaStore; DB row; `captureResult` event.
- **Logic:** Capture the next fully composited frame from the render thread (read-back through PBO/`glReadPixels`), encode JPEG on an IO thread, write with `MediaStore` `IS_PENDING` flow, set EXIF orientation 0 (pixels already upright). Resolution = render resolution (default 720x1280 portrait [REC]); higher-res photo is v1.1. Flash: torch is turned on briefly for rear photos when flash is On/Auto-needed [REC; confirm on device].
- **Behavior:** haptic + shutter animation; failure → snackbar + Retry; free space checked first.
- **Acceptance:** AC-08, AC-15.

## F-06 Video recording (FR-10, FR-11) — AC-09, AC-10, AC-15, AC-17

- **Input:** record/stop, audio enabled flag, current style.
- **Output:** MP4 (H.264 video, AAC-LC audio, 1280x720 @ 30 fps target, ~8 Mbps video / 128 kbps audio [EST, tune in M6]) in `Movies/Cam-Anime/`; DB row with duration, size, resolution.
- **Logic:** path chosen in spike S1 ([CAMERA_PIPELINE](../architecture/CAMERA_PIPELINE.md)). Audio from `AudioRecord` (or CameraX audio) with PTS on the same monotonic clock as video frames. Timer shows elapsed from first encoded video frame.
- **Behavior:** pause is not in MVP. Stop finalizes the MP4. Interruptions finalize.
- **Acceptance:** AC-09, AC-10, AC-15, AC-17.

## F-07 Local storage and gallery (FR-12, FR-14) — AC-14

- **Input:** DB rows, MediaStore items.
- **Output:** grid/viewer, share intent, delete.
- **Logic:** [DATABASE](../data/DATABASE.md); reconciliation on gallery open (rows whose URI no longer resolves are removed).
- **Acceptance:** AC-14.

## F-08 Settings (FR-13) — AC-12, AC-13

| Setting | Values | Default | Effect |
|---|---|---|---|
| Default camera | rear / front | rear | Lens on app start |
| Quality cap | auto / 720p / 480p | auto | Upper bound on render resolution |
| Grid overlay | on / off | off | Rule-of-thirds overlay (Flutter-drawn) |
| Haptics | on / off | on | Shutter/record feedback |
| Mirror front photos | on / off | off [REC] | Whether saved front-camera photos are mirrored like the preview |
| Performance mode | auto / always-saving | auto | Forces lower tier |

## F-09 Adaptive quality / thermal (FR-17) — AC-13

- **Input:** `PowerManager` thermal status listener, frame-time statistics, battery saver state.
- **Output:** quality tier change (720p30 → 720p24 → 480p30 → effect off), `qualityTier` event.
- **Logic:** thresholds in [PERFORMANCE](../performance/PERFORMANCE.md); hysteresis to avoid oscillation; never changes tier during active recording except to protect the session (then keeps encoder size fixed and scales the render input) [OPEN: validate in S1].
- **Acceptance:** AC-13.

## F-10 Onboarding, About and Privacy (FR-16)

Static screens; strings and policy text in the repository. About shows the app version and the open-source license list (generated from dependency metadata, OQ-12).

## F-11 Mode selector (FR-18)

Bottom sheet with Mode A (selected). Mode B and Animals shown with a "Coming soon" label, not tappable, no hidden behavior.
