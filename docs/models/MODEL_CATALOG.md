# Model Catalog

**Nothing in this catalog has been verified or downloaded.** During planning the official model cards and license files could not be retrieved, and secondary-source statements (for example, "Apache-2.0") are recorded only as leads. A model may not be bundled in any release until its row reaches **License: CONFIRMED** and **Evaluation: COMPLETE**, with the license text stored in `third_party/licenses/` (created when the first model is added).

Status values: `PENDING` (not researched) · `LEAD` (candidate from a secondary source/recollection) · `CONFIRMED` (read from the official model card/license file; date + URL recorded) · `REQUIRES REAL-DEVICE VALIDATION` · `REJECTED`.

Per-model evaluation fields: purpose, Android support, offline, commercial use, redistribution, size, runtime, inference cost, memory, accuracy/limitations, source URL, SHA-256, evaluation status (as in [AI_AND_COMPUTER_VISION §7](../architecture/AI_AND_COMPUTER_VISION.md#7-model-evaluation-checklist-mandatory-per-model)).

## 1. Human segmentation (MVP-critical)

| ID | Candidate | Purpose | Source | License | Size | Runtime | Hardware | Evaluation |
|---|---|---|---|---|---|---|---|---|
| SEG-1 | MediaPipe Image Segmenter — selfie segmentation model(s) | Person/background mask | [MediaPipe Image Segmenter](https://ai.google.dev/edge/mediapipe/solutions/vision/image_segmenter) | LEAD: Apache-2.0 for the framework; **model-card license for the weights unconfirmed** | unknown | MediaPipe Tasks (LiteRT inside) | CPU; GPU unknown | PENDING (S2) |
| SEG-2 | MediaPipe multi-class selfie segmenter | Part-level masks (hair/skin/clothes) | same page | unconfirmed | unknown (documented as larger [REF]) | MediaPipe Tasks | unknown | PENDING |
| SEG-3 | Matting-style models (e.g., robust video matting family) | Better hair/edge alpha | various | unconfirmed (varies, some research-only) | unknown | LiteRT/ONNX conversion needed | unknown | PENDING (only if SEG-1 quality fails) |

## 2. Human detection

No separate model in the MVP (derived from the mask). If needed later: MediaPipe Object Detector (class `person`) — status PENDING, license unconfirmed.

## 3. Human pose estimation (v2.0)

| ID | Candidate | Purpose | Source | License | Size | Runtime | Evaluation |
|---|---|---|---|---|---|---|---|
| POSE-1 | MediaPipe Pose Landmarker (BlazePose family; docs state 33 landmarks [REF]) | Skeleton for Mode B | [Pose Landmarker](https://ai.google.dev/edge/mediapipe/solutions/vision/pose_landmarker) | unconfirmed | unknown | MediaPipe Tasks | PENDING |

## 4. Face landmarks (later)

| ID | Candidate | Purpose | Source | License | Evaluation |
|---|---|---|---|---|---|
| FACE-1 | MediaPipe Face Landmarker | Expression-driven characters | [Face Landmarker](https://ai.google.dev/edge/mediapipe/solutions/vision/face_landmarker) | unconfirmed | PENDING |

## 5. Animal detection (v3.0)

| ID | Candidate | Purpose | Source | License | Evaluation |
|---|---|---|---|---|---|
| ANI-DET-1 | MediaPipe Object Detector with a COCO-labeled model (e.g., EfficientDet-Lite family) | Dog/cat/bird boxes | [Object Detector](https://ai.google.dev/edge/mediapipe/solutions/vision/object_detector) | unconfirmed. Class availability (dog, cat, bird) must be checked in the exact model's label map | PENDING |

## 6. Animal pose (v3.0, research-gated)

| ID | Candidate | Note | Evaluation |
|---|---|---|---|
| ANI-POSE-? | No confirmed off-the-shelf, commercially usable model identified | Public animal-pose datasets exist, but their licenses may restrict commercial use [REF, unverified]; likely requires custom training on licensed data. Human pose models do **not** apply | PENDING (R-05) |

## 7. Object tracking

Classical association + smoothing (no model). Status: design only.

## 8. Learned stylization (post-MVP research, R-06)

Candidates (AnimeGAN-style, CartoonGAN-style) are unevaluated; many public weights have unclear or non-commercial licenses. Status: PENDING.

## 9. Inference runtimes (also license-reviewed)

| Runtime | License (LEAD) | Status |
|---|---|---|
| MediaPipe Tasks Vision | Apache-2.0 | PENDING confirmation |
| LiteRT | Apache-2.0 | PENDING confirmation |
| ONNX Runtime Mobile | MIT | PENDING confirmation |

## 10. Row template

```
### <ID> <name>
- Purpose / task:
- Source URL + retrieval date:
- License (code) / License (weights) / model card URL:
- Commercial use: yes/no/unclear — Redistribution inside an APK: yes/no/unclear — Attribution required:
- Size (MB) / input / output / labels:
- Runtime and version / delegates:
- Measured on <device> (build mode, commit): inference ms p50/p95, memory
- Accuracy and known limitations (from card + our test clips):
- SHA-256:
- Decision: ADOPTED / REJECTED / PENDING — reason
```
