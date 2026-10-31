# AI and Computer Vision

Rules for this document: no claim of model capability without confirmation in the model's own documentation; no invented benchmarks; unknown stays unknown. Everything below is **[REF] / [OPEN]** until the "Verification" column in [MODEL_CATALOG](../models/MODEL_CATALOG.md) says otherwise. Note: during planning, the official documentation pages could not be fetched, so no model license in this repository is confirmed.

## 1. Tasks and strategy

| Task | MVP? | Strategy |
|---|---|---|
| Human detection | Implicit | Derived from segmentation mask coverage (`subjectPresent`). Separate detector only if measurements demand |
| Human segmentation | **Yes** | Pretrained person/selfie segmentation model, low-res input, mask upsampled on GPU |
| Human pose estimation | No (v2.0) | Candidate: MediaPipe Pose Landmarker (BlazePose family). Needed for Mode B rigs |
| Face landmarks | No (later) | Candidate: MediaPipe Face Landmarker. For expression-driven characters |
| Animal detection | No (v3.0) | Candidate: a general object detector with COCO classes dog/cat/bird. Class support must be confirmed in the specific model's label map |
| Animal pose/keypoints | No (v3.0, research-gated) | **No confirmed commercially usable off-the-shelf model.** Animal pose datasets often carry research-only licenses [REF, unverified]. Plan: research, then possibly train/fine-tune a small model on permissively licensed data. Human pose models do **not** transfer to animals |
| Tracking | v2.0+ | Classical association (IoU + Kalman / simple centroid) on detections; keypoint smoothing (One-Euro filter). OpenCV not required |

## 2. Inference runtimes under evaluation

| Runtime | Fit | License (to verify) | Notes |
|---|---|---|---|
| **MediaPipe Tasks Vision (Android)** | Ready-made Image Segmenter, Pose/Face Landmarker, Object Detector APIs with live-stream mode; least integration work | Apache-2.0 [REF] | Model files are `.tflite` bundles; bundles each task's native libs (size cost); the task API handles model I/O |
| **LiteRT (successor of TensorFlow Lite)** | Direct control of the model, delegates (CPU/XNNPACK, GPU); smaller surface | Apache-2.0 [REF] | A secondary source reports the `CompiledModel` API as the recommended path and GPU as a separate artifact [REF]; confirm in the [LiteRT docs](https://ai.google.dev/edge/litert) |
| **ONNX Runtime Mobile** | Good if a chosen model only exists as ONNX | MIT [REF] | Extra runtime = more APK size; prefer only if needed |
| NCNN / MNN / others | Alternative mobile runtimes | various | Not evaluated; add only with a reason |

**Selection method (spike S2):** pick the smallest-effort option that meets the performance bar on the reference device: implement a segmentation test harness in the native module with (a) MediaPipe Image Segmenter and (b) LiteRT with the same `.tflite` model, run with CPU and (if available) GPU, measure per-frame inference time, mask quality, thermals while the render pipeline is running, and APK size delta. Decision recorded in ADR-005. Default expectation: MediaPipe Tasks for the MVP because it minimizes custom code; LiteRT direct if MediaPipe overhead or size is unacceptable.

## 3. Human segmentation candidates

| Candidate | Source | Comment |
|---|---|---|
| MediaPipe Selfie Segmenter (e.g. the "selfie segmenter" `.tflite`) | [Image Segmenter docs](https://ai.google.dev/edge/mediapipe/solutions/vision/image_segmenter) | Designed for people close to the camera; input is small; likely fast. Full-body at distance may be weaker. Variants (landscape/square) exist per the docs [REF] |
| MediaPipe Multi-class selfie segmenter | same page | Multi-class (hair, body-skin, face-skin, clothes, others) could enable per-part styling; heavier [REF] |
| Other segmentation models (e.g., from `.tflite` hubs, or MODNet/RVM-style matting) | various | Matting models give better hair edges but may be heavier and have varied licenses; evaluate only if the selfie segmenter fails visually |

Quality bar for acceptance (to be judged in M3 with a recorded test set of 5-10 clips): stable silhouette in typical indoor light, hair/hand tolerated, no flicker visible at 24 FPS, full body visible at 1.5-3 m acceptable degradation documented.

## 4. Mask post-processing (native, cheap)

1. Convert model output to 0-1 float.
2. Temporal smoothing: `m_t = α·raw + (1−α)·m_{t−1}`, α ≈ 0.6 [EST, tune]. (Optionally per-pixel adaptive α using motion.)
3. Upload at model resolution; GPU bilinear upsample; shader adds smoothstep contrast `smoothstep(lo, hi, m)` and feather.
4. `subjectPresent` = coverage > 2 % for ≥ 5 consecutive masks (hysteresis) [EST].
5. Optional guided/joint-bilateral edge refinement in a shader: v1.1.

## 5. Mode B pose path (v2.0 preview)

Pose Landmarker provides 33 landmarks per documentation [REF]. The rig maps landmarks to a 2D bone hierarchy; smoothing with One-Euro filtering; confidence gating; character drawn in GL over the camera frame. Open problems: reveal of the occluded background (inpaint or cover), missing/occluded limbs, scale/perspective, art pipeline. These are not designed in detail now to avoid fake precision.

## 6. Animal path (v3.0 preview)

Stage 1: detector + tracker for dog/cat/bird → bounding boxes and segmentation (instance segmentation or box-prompted segmenter). Stage 2: species-specific keypoints (research-gated). Stage 3: species-specific rigs and "human-like cartoon" characters. Do not start before the human pipeline ships.

## 7. Model evaluation checklist (mandatory per model)

License (code and weights separately) · commercial use · redistribution/bundling · attribution duties · model size · runtime compatibility · input/output spec · inference time (measured on reference device, CPU/GPU) · memory · device compatibility (min API, ABI, GPU delegate support) · works offline · maintenance status · training-data concerns (face/biometric data) · SHA-256 recorded. Results go into [MODEL_CATALOG](../models/MODEL_CATALOG.md). A model with an unconfirmed license **cannot be bundled in a release**.

## 8. Offline inference and safety

- Models ship inside the APK (`assets/models`), integrity-checked at load ([MODEL_ASSET_MANAGEMENT](../models/MODEL_ASSET_MANAGEMENT.md)). No model download in MVP.
- Inference runs in-process; model inputs/outputs are never logged or transmitted.
- Biometric/face-data note: segmentation only; no face recognition, no identity storage.

## 9. Research tasks (not performed yet)

R-01 Confirm licenses/model cards for candidate segmentation models. R-02 Measure candidates on the reference device (S2). R-03 Confirm MediaPipe Tasks segmentation output format and live-stream semantics. R-04 Evaluate matting-grade models. R-05 Survey animal keypoint models and licenses. R-06 Evaluate learned stylization (AnimeGAN-style) models: license, size, speed. All **PENDING**.
