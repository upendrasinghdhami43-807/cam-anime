# Technical Decisions (ADRs)

Status values: **Accepted** (decided, may change only via a new ADR), **Proposed** (decision gated on a spike/approval), **Superseded**. Template at the bottom.

---

## ADR-001 Flutter UI + native Kotlin engine — Accepted
- **Context:** Real-time camera + GPU + ML needs low-level control; UI should be cross-platform.
- **Alternatives:** (a) Flutter `camera` package + Dart image processing; (b) fully native Android UI; (c) Flutter + native engine.
- **Decision:** (c).
- **Reasons:** Flutter's camera plugins expose frames/images to Dart, which is too slow/copy-heavy for real-time processing; native owns the pixel path. Flutter keeps the UI portable to iOS.
- **Trade-offs:** Two languages, a bridge contract to maintain, platform-specific engines (Android now, iOS later).
- **Revisit if:** Flutter gains a first-class zero-copy GPU camera pipeline that meets requirements.

## ADR-002 Preview via Flutter `Texture`, no frames in Dart — Accepted
- **Alternatives:** Platform View (`AndroidView`/PreviewView), sending bytes via channels, FFI pointer to frame buffers.
- **Decision:** External texture from `TextureRegistry`; engine renders into it with EGL.
- **Reasons:** Zero CPU copy; engine controls orientation/mirroring; the same render target feeds recording. Platform views add composition overhead/limits and cannot show our composited output anyway.
- **Trade-offs:** Must manage surface lifecycle and size changes ourselves; the exact producer API (`createSurfaceProducer` vs `createSurfaceTexture`) is confirmed in S3.
- **Revisit if:** Texture path shows frame pacing issues on target devices.

## ADR-003 OpenGL ES 3.0 for rendering — Accepted
- **Alternatives:** Vulkan; Skia/Impeller custom shaders in Flutter; RenderScript (deprecated) / compute shaders.
- **Decision:** GLES 3.0 with EGL.
- **Reasons:** Universal support, direct interop with `SurfaceTexture`/`MediaCodec` surfaces, simplest correct path, enough for the passes needed. Vulkan interop with camera/encoder surfaces is more complex and has no benefit at this workload. Doing it in Flutter shaders would require frames in Dart.
- **Trade-offs:** GLES driver quirks across vendors; Apple platforms need Metal later (algorithms are specified, code is not shared).
- **Revisit if:** profiling shows GLES is the bottleneck, or GLES is removed from target devices.

## ADR-004 No OpenCV and no custom C++ in the MVP — Accepted
- **Context:** The brief lists C++ and OpenCV "where justified".
- **Decision:** Not used in the MVP. Add only through a new ADR with a profiling or capability justification (e.g., guided filter, optical flow, tracking).
- **Reasons:** All MVP image operations are per-pixel/stencil and belong on the GPU; mask post-processing is trivial on a 256² buffer in Kotlin. OpenCV adds APK size (~MBs per ABI [EST]), NDK/CMake build complexity, and JNI surface. Classical-CV-in-C++ would run on the CPU, which is already busy feeding the GPU/encoder.
- **Trade-offs:** If CPU-side image ops are later needed, JNI/CMake setup happens then.
- **Revisit if:** Mask refinement or tracking needs CPU algorithms, or iOS sharing of C++ code becomes valuable.

## ADR-005 Segmentation runtime — Proposed (spike S2)
- **Options:** MediaPipe Tasks Vision (Image Segmenter) vs LiteRT direct vs ONNX Runtime Mobile.
- **Default:** MediaPipe Tasks Vision if it meets budget; otherwise LiteRT.
- **Decide with:** per-frame time, APK size delta, mask quality, integration effort on the reference device; license of runtime and model confirmed.

## ADR-006 Recording path — Proposed (spike S1)
- **Options:** (A) CameraX `CameraEffect` + `VideoCapture`; (B) custom GL → MediaCodec + AudioRecord + MediaMuxer.
- **Default:** try A first, fall back to B.
- **Decide with:** can the Flutter preview and stylized recording coexist at 720p30; A/V sync ≤ 80 ms; stability over 10 min; lifecycle; code size.

## ADR-007 Storage: MediaStore for media, SQLite (Drift) for metadata — Accepted
- **Alternatives:** App-private files only; SAF; no DB (query MediaStore only).
- **Decision:** Files in `Pictures/Cam-Anime` and `Movies/Cam-Anime` through MediaStore; Drift/SQLite stores metadata (style, duration, etc.) and app settings.
- **Reasons:** Users expect captures in the system gallery; MediaStore needs no storage permission for own files on API 29+; the DB holds data MediaStore cannot (style id, mode, render size, engine version).
- **Trade-offs:** Files can be deleted outside the app → reconciliation step. Privacy: media is visible to other apps that hold media permissions (disclosed in About/Privacy).
- **Revisit if:** A "private vault" feature is requested.

## ADR-008 Permissions handled natively — Accepted
- **Decision:** Kotlin `ActivityResult` APIs behind bridge calls; no `permission_handler`.
- **Reasons:** Fewer dependencies; the camera/audio flows are owned by the engine anyway; precise control of "blocked" state.
- **Trade-offs:** Slightly more native code; iOS needs its own implementation (planned in the same bridge).

## ADR-009 Riverpod + go_router — Accepted
- **Alternatives:** Bloc, Provider, GetX, Navigator 1.0.
- **Reasons:** Compile-safe, testable, minimal boilerplate; go_router is the Flutter-team-maintained routing package [REF]. Minor decision; low cost to change early, high cost later, hence fixed now.

## ADR-010 One Flutter package + one Android library module — Accepted
- **Alternatives:** Melos multi-package monorepo; four separate engine Gradle modules; Flutter federated plugin.
- **Decision:** Single Dart package `apps/mobile`; native engine as the Gradle library module `camanime_engine` inside `apps/mobile/android`; engine packages (`bridge, camera, gl, vision, record, media, perf`) enforce boundaries.
- **Reasons:** Buildable with standard Flutter tooling; avoids premature modularization; the bridge is the only seam.
- **Revisit if:** The engine is reused by another app, or build times demand splitting.

## ADR-011 minSdk 29 (Android 10) — Accepted, revisit with OQ-04
- **Reasons:** MediaStore own-media writes without legacy storage permission; thermal status API (`PowerManager.addThermalStatusListener`, API 29); modern camera/codec behavior; targets ~all devices able to run real-time ML + GLES 3.0 [EST]. The share of devices lost is unknown here and must be checked against Play Console/market data (OQ-04).
- **Revisit if:** The owner's target market has many Android 8-9 devices.

## ADR-012 Mode A uses classical GPU stylization, not learned style transfer — Accepted for MVP
- **Reasons:** Zero budget, offline, real-time on mid-range GPUs; learned stylization models (AnimeGAN-like) have unclear commercial licenses, size (MBs-tens of MBs) and per-frame cost [OPEN R-06]. A shader pipeline is deterministic, small and tunable.
- **Trade-offs:** Output is "cel/ink/comic filter", not a hand-drawn anime redraw. The owner must accept this look for v1.0 (OQ-07).
- **Revisit if:** A licensed learned model meets the 24 FPS target on Tier A+B devices.

## ADR-013 Photo = rendered composite frame — Accepted
- **Alternatives:** CameraX ImageCapture at sensor resolution, then re-render offline.
- **Decision:** MVP photo is a read-back of the composited frame at render resolution.
- **Reasons:** WYSIWYG, no second inference/render path, minimal code. Trade-off: 720p-class photos. v1.1 may add a high-res path.

## ADR-014 Engine delivered as an in-repo module registered by the host app — Accepted, revisit at M1
- **Decision:** `CamAnimePlugin` (a `FlutterPlugin`+`ActivityAware`) inside `camanime_engine`, registered manually from the host `MainActivity`. If registration proves awkward in M1, turn the engine into a local Flutter plugin package under `apps/` via a new ADR.

## ADR-015 Database has two MVP tables — Accepted
- `media_items`, `app_settings`. Catalog data (styles, modes) lives in code/asset JSON; model assets in a bundled manifest; character assets arrive with v2.0. See [DATABASE](../data/DATABASE.md).

## ADR-016 JDK 17 for builds — Accepted (verify at M0)
- **Context:** [ENV] this machine has only JDK 25. Gradle/AGP supported-JDK ranges are version-specific and JDK 25 is likely newer than the Flutter-supported toolchain [REF, unconfirmed].
- **Decision:** Install/use JDK 17 (the JBR bundled with Android Studio is acceptable) and point Flutter at it with `flutter config --jdk-dir`; leave system JDK 25 untouched.
- **Revisit if:** the `flutter doctor` output at M0 recommends a different version.

---

## Template

```
## ADR-NNN Title — Status
- Context:
- Alternatives considered:
- Decision:
- Reasons:
- Trade-offs:
- Revisit if:
```
