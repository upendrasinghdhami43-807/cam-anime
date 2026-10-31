# Camera Pipeline

The most important technical component. Status: design draft; every item marked **[S1]/[S2]/[S3]** is decided by a spike on the real device, not by this document. API names below are recalled from CameraX/Android documentation and must be confirmed against the official docs at implementation time ([REF]): [CameraX](https://developer.android.com/media/camera/camerax), [CameraEffect/SurfaceProcessor](https://developer.android.com/media/camera/camerax/media3-effect), [Flutter texture registry](https://api.flutter.dev/javadoc/io/flutter/view/TextureRegistry.html).

## 1. Improved pipeline (vs the conceptual one)

The conceptual pipeline had a linear chain with "Flutter Preview" late. Problems and changes:

| Issue | Change |
|---|---|
| Detection → segmentation → CV → shader as serial CPU stages would add latency and copy frames | Split into **two parallel paths**: a heavy-but-asynchronous **analysis path** (low-res frames → mask) and a light **render path** (full-res camera texture + latest mask → shader). Render never waits for inference |
| Separate "human detection" stage | Folded into segmentation (`subjectPresent` from mask coverage); a detector is added only if measurements show a need |
| Flutter preview after compositing | Flutter displays a native-produced texture; compositing happens before and is shared by preview, encoder, and photo |
| Recording after Flutter | Recording taps the same composited frame on the GPU, not Flutter's output |

```
                      ┌────────────────── analysis path (async, drops frames) ──────────────────┐
CameraX ImageAnalysis ─▶ resize/convert (≤256²) ─▶ inference thread ─▶ mask post-process ─▶ mask texture ┐
        (YUV_420_888,                                                                                   │ latest
         KEEP_ONLY_LATEST)                                                                              ▼
CameraX Preview ─▶ SurfaceTexture (OES) ─▶ GL render thread: [stylize] ─▶ [composite with mask] ─▶ ┬─▶ Flutter texture surface
   (zero-copy GPU)                           (full-res, vsync-driven by camera frames)             ├─▶ encoder input surface (record)
                                                                                                   └─▶ capture read-back (photo)
```

## 2. CameraX use cases

| Use case | Config | Purpose |
|---|---|---|
| Preview | Target 1280x720, rotation = display rotation; `SurfaceProvider` supplies our OES `SurfaceTexture` surface | Full-res image into GL |
| ImageAnalysis | `OUTPUT_IMAGE_FORMAT_YUV_420_888`, resolution ~640x480 or lower, `STRATEGY_KEEP_ONLY_LATEST`, dedicated executor | Feeds segmentation; backpressure handled by KEEP_ONLY_LATEST |
| ImageCapture | **Not used in MVP** (photo = rendered frame, ADR-013). Considered for v1.1 high-res | |
| VideoCapture | Only if spike S1 chooses the CameraEffect route | |

Binding: `ProcessCameraProvider.bindToLifecycle(lifecycleOwner, selector, useCases...)`. Unbind on pause. Lens switching = unbind + bind with the new selector (camera session recreation is inherently ~200-500 ms [EST]); the last frame stays on screen during the switch.

## 3. Output path to Flutter [S3]

Flutter provides external textures through `TextureRegistry` (`createSurfaceProducer()` on current Flutter, or `createSurfaceTexture()`; exact API confirmed in S3). The engine obtains a `Surface`, creates an **EGL window surface** on it from the render thread, and draws the composited frame into it. Dart renders `Texture(textureId: ...)`.

- Flutter's `Texture` widget does not rotate or mirror. Therefore the render pass outputs an **already upright, already mirrored** image (front preview mirrored) of size `previewSize` reported to Dart. This also gives one orientation implementation for preview, video and photo.
- M1 (no GL yet): CameraX `Preview` writes straight into the Flutter surface; orientation uses `SurfaceRequest.TransformationInfo.rotationDegrees` mapped to quarter-turns in Dart (`RotatedBox`) and mirroring through `Transform`. Replaced in M2.
- Recreate the texture when the surface size changes (camera switch changes buffer sizes).

## 4. Frame lifecycle and memory

| Stage | Memory | Owner | Release |
|---|---|---|---|
| Camera frame (preview) | GPU buffer via SurfaceTexture | CameraX/GL thread | `updateTexImage()` per frame; no CPU copy |
| Analysis frame | `ImageProxy` | Analysis executor | `close()` in `finally` **always** (leak freezes analysis) |
| Model input | Reused `ByteBuffer`/`FloatBuffer` (direct, allocated once per resolution) | Inference thread | Freed on engine stop |
| Mask | Reused float array → uploaded to a single-channel texture (R8/R16F) with `glTexSubImage2D` | Render thread | Texture deleted on GL teardown |
| Photo read-back | PBO (2 buffers, ping-pong) to avoid stalling | Render thread → IO thread | Pool reused |
| Encoder frames | Encoder input surface (GPU) | MediaCodec | Codec release on stop |

Rules: no per-frame allocation in the render loop or analysis loop (watch GC logs), buffer pools are sized once, queues have capacity 1-2, and the analysis path drops rather than queues.

## 5. Threads

| Thread | Work | Never does |
|---|---|---|
| Main | Bridge dispatch, lifecycle | Camera binding work beyond the call, GL, inference, file IO |
| `camera-exec` | CameraX callbacks | Heavy compute |
| `analysis-exec` | Convert/resize YUV → model input | Inference (if separate) |
| `inference` | Model invoke, mask post-process | GL calls (it hands a mask array over) |
| `gl-render` | EGL context owner; all GL calls; draws; swaps to outputs | Blocking IO |
| `encoder`/`audio` | MediaCodec drain, AudioRecord read | GL |
| `io` | JPEG encode, MediaStore | GL |

Exactly one thread owns the EGL context. Other threads post commands via a `Handler`.

## 6. Orientation, mirroring, timestamps

- **Rotation:** use `ImageInfo.getRotationDegrees()` for analysis frames (so the model sees an upright person) and the SurfaceTexture transform matrix for the preview stream; combine with sensor orientation and `Display.rotation`. Portrait-locked UI in MVP simplifies (the Activity is locked to portrait [REC]); AC-04 still tests device rotation attempts.
- **Front camera:** mirror in the render pass for preview. Saved photos/videos are *not* mirrored by default (what the camera sees), configurable via "Mirror front photos" (F-08) [REC]. Mask must be flipped consistently with the image in the shader (single `uMirror` uniform applied to both).
- **Timestamps:** the video frame PTS = `SurfaceTexture.getTimestamp()` (camera monotonic nanoseconds, typically `CLOCK_BOOTTIME`/`MONOTONIC` depending on `SENSOR_INFO_TIMESTAMP_SOURCE`) and audio PTS must be derived from the same timebase: `AudioRecord.getTimestamp()` with `TIMEBASE_MONOTONIC`/`BOOTTIME` per the device's sensor timestamp source. The first video and audio PTS are rebased to 0 together. **[S1]** verifies drift/offset on the device. Frames used by the mask carry the analysis frame timestamp to compute mask age.

## 7. Segmentation integration

See [AI_AND_COMPUTER_VISION](AI_AND_COMPUTER_VISION.md). Contract to the renderer:

```
MaskFrame { width, height, data: FloatArray|ByteArray (0..1), timestampNs, generation }
```

The renderer samples the **latest** mask. Because mask is 1-3 frames behind, silhouettes lag on fast motion. Mitigations: temporal smoothing, small edge feather that hides a slight offset, optional motion-compensated warp (post-MVP), and a staleness fade-out. **Measure this lag in M3** (OQ-10).

## 8. Rendering and compositing

Algorithm in [RENDERING_ENGINE](RENDERING_ENGINE.md). One pass chain on the GPU for every output. The renderer draws once per camera frame (driven by `onFrameAvailable`), then blits the final texture to each active output surface (preview always; encoder when recording).

## 9. Recording [S1]

Two candidate paths:

- **Path A — CameraEffect:** register a `CameraEffect` with a `SurfaceProcessor` targeting PREVIEW (+ VIDEO_CAPTURE, + optionally IMAGE_CAPTURE). CameraX hands us input surface requests and output surfaces; we render the effect into them. CameraX `VideoCapture` + `Recorder` then handle H.264/AAC encode, audio capture and MP4 muxing. Pros: least custom code, OEM-tested audio path. Cons: we depend on CameraX effect semantics, less control over bitrate/size/timestamps; interplay with delivering the Flutter surface must be proven.
- **Path B — custom:** our GL thread draws to a `MediaCodec` input surface; `AudioRecord` → AAC encoder; `MediaMuxer` writes MP4. Pros: full control, no CameraX video dependency. Cons: A/V sync, drain loops, format-change handling, OEM codec quirks are ours.

**Default plan:** prototype Path A first (S1); fall back to Path B if it cannot give the Flutter preview + stylized recording at 720p30 with acceptable sync. The decision and measurements are recorded as ADR-006.

Common requirements: H.264 baseline/main at 1280x720, 30 fps, ~8 Mbps [EST]; AAC-LC 44.1/48 kHz mono/stereo 128 kbps [EST]; fixed output orientation upright (no rotation metadata); finalize in `finally`; write to MediaStore with `IS_PENDING=1` then `0`.

Audio/video sync acceptance: offset ≤ 80 ms (AC-09) measured by a clap-and-flash test ([TESTING](../development/TESTING.md)).

## 9a. Photo capture

Render thread receives `captureFrame(request)`, renders the current composite into an offscreen FBO (or reuses the last frame), reads back via PBO, hands the RGBA bytes to the IO executor → `Bitmap`/JPEG → MediaStore. Resolution equals render resolution in MVP (ADR-013).

## 10. Performance optimizations

- Stylization at render resolution; the mask is low-res and upsampled in the shader.
- Use half-precision where acceptable; minimize texture reads in the stylize pass (separable or reduced-tap filters).
- Avoid `glFinish`; avoid synchronous read-backs except during capture (PBO).
- Reuse FBOs/textures; no allocation on the frame path.
- Run inference at a decoupled rate (e.g., every frame if the device can, else every 2nd/3rd) with the last mask reused.
- Quality tiers (see [PERFORMANCE](../performance/PERFORMANCE.md)): 720p30 → 720p24 → 480p30 → effect off.
- Thermal: `PowerManager.addThermalStatusListener` (API 29+) and frame-time EMA trigger tier changes with hysteresis.
- Prefer GPU delegates for inference only if S2 shows a benefit; CPU XNNPACK inference may be more predictable than GPU while the GPU is busy rendering [OPEN].

## 11. Lifecycle correctness checklist

- Camera only bound while the activity is `STARTED` and permission granted.
- On `onPause`: stop recording (finalize), unbind camera, stop analysis, release encoder, keep or destroy EGL context (destroy by default; recreate on resume; decided in M2).
- On `onDestroy`/engine detach: release everything; `SurfaceProducer`/texture unregistered exactly once.
- GL context loss or surface destruction → renderer tears down and rebuilds outputs; no crash.
- Verify with `adb shell dumpsys media.camera` (no lingering clients), `dumpsys SurfaceFlinger`, and logcat on 50 pause/resume cycles (AC-05).

## 12. Failure modes

| Failure | Handling |
|---|---|
| Inference too slow | Frame dropping, lower inference rate, lower input size, tier downgrade |
| Camera error | `CAMERA_ERROR` event; UI error panel; retry creates a new session |
| GL init failure | `GL_INIT_FAILED`; fallback to plain preview if possible |
| Encoder unsupported size/profile | Probe `MediaCodecList` at record start; fall back to 480p |
| Surface lost | Re-create producer and EGL surface |
