# Glossary

## Product
- **Mode A / Real-subject stylization:** cartoonizes the user's actual pixels.
- **Mode B / Character replacement:** replaces the person with an animated character driven by pose.
- **Style:** a parameter set (JSON) applied by the stylization shader (`cel_pop`, `ink_comic`, `soft_pastel`, `noir_sketch`).
- **Quality tier:** render/frame-rate configuration (`q720p30`, `q720p24`, `q480p30`, `effect_off`).

## Computer vision / ML
- **Segmentation / mask:** per-pixel foreground probability (0-1) for the person.
- **Matting:** segmentation with soft alpha suitable for hair/edges.
- **Pose estimation / landmarks:** 2D/3D body joint positions (e.g., 33 points in BlazePose-style models).
- **Face landmarks:** dense facial points for expressions.
- **Detector / bounding box:** locates objects (people, animals) as rectangles.
- **Tracking:** associating detections across frames; **One-Euro filter:** adaptive low-pass for jitter-free keypoints.
- **EMA:** exponential moving average (temporal smoothing).
- **Inference runtime:** library that executes a model (MediaPipe Tasks, LiteRT, ONNX Runtime).
- **LiteRT:** Google's runtime, successor to TensorFlow Lite. **Delegate:** hardware backend for a runtime (CPU/XNNPACK, GPU).
- **Model card:** documentation of a model's intended use, data and license.

## Camera
- **CameraX:** Jetpack camera library. **Use case:** Preview, ImageAnalysis, ImageCapture, VideoCapture.
- **ImageProxy:** CameraX wrapper of a frame; must be closed.
- **Backpressure / KEEP_ONLY_LATEST:** drop old frames instead of queueing.
- **YUV_420_888:** common camera frame format.
- **Sensor orientation / rotation degrees:** how the sensor image is rotated relative to the display.
- **Mirroring:** horizontal flip for front-camera preview.
- **PTS (presentation timestamp):** time stamp placed on frames/audio samples; **A/V sync:** alignment of audio and video PTS.
- **SurfaceTexture:** consumer of camera frames producing a GL external texture. **OES texture:** `GL_TEXTURE_EXTERNAL_OES`.
- **MediaCodec / MediaMuxer:** Android hardware encoder API / container writer (MP4).
- **MediaStore:** Android shared media database; **scoped storage:** access model without broad storage permission.

## Rendering
- **Shader (GLSL):** GPU program. **Pass:** one full-screen draw. **FBO:** off-screen render target.
- **EGL:** interface between GL ES and the window system; **EGLSurface:** render target surface.
- **PBO:** pixel buffer object for async read-back.
- **Cel shading / quantization:** flat color bands. **Sobel / DoG:** edge detectors. **Bilateral filter:** edge-preserving blur. **Halftone:** dot-pattern shading.
- **Compositing / feathering:** blending foreground over background with soft mask edges.
- **Golden test:** image comparison against a reference output.

## Mobile architecture
- **Platform channel:** Flutter ↔ native messaging (MethodChannel/EventChannel).
- **FFI:** Dart foreign function interface to native C code.
- **Texture widget / SurfaceProducer:** Flutter's way of showing externally rendered frames.
- **Platform view:** embedding a native view in Flutter (not used).
- **Plugin / host app:** Flutter plugin registering native code; the Android application module.
- **ADR:** architecture decision record. **Spike:** time-boxed experiment to settle a technical unknown.
- **Drift:** Dart SQLite library. **Riverpod / go_router:** state management / navigation libraries.
- **Thermal throttling:** OS/hardware lowers performance when hot.
- **Profile build:** Flutter AOT build with profiling hooks, used for performance measurements.
