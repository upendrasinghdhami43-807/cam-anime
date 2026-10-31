# Roadmap

Version scope is fixed here; the PRD, [IMPLEMENTATION_PLAN](../development/IMPLEMENTATION_PLAN.md) and [PROJECT_STATUS](../project/PROJECT_STATUS.md) must agree with it. Dates are intentionally absent: scheduling depends on the owner's available time and the reference device (OQ-01).

## Releases

| Release | Theme | Scope |
|---|---|---|
| **v1.0 (MVP)** | Mode A, one person, Android | FR-01…FR-18 of the [PRD](PRD.md): camera, segmentation, 4 styles, photo, video + audio, gallery, settings, offline, adaptive quality |
| **v1.1** | Quality and polish | 2-4 additional styles; mask refinement (edge-aware/temporal); front-camera quality tuning; style intensity slider; high-res photo path (CameraX ImageCapture + offline re-render) if feasible; countdown timer; localization scaffolding |
| **v2.0** | Characters + groups | **Mode B** with one 2D character (pose landmarks → rig); multiple people in Mode A; character asset format (`character_assets` table added); background reveal strategy for Mode B |
| **v3.0** | Animals + iOS | Animal detection/tracking and one species (dog first, then cat, bird); research-gated animal keypoints; **iOS alpha** (Swift/AVFoundation/Metal) |
| **Later** | Ecosystem | Facial-expression driven characters, character customization, asset packs, optional cloud backup, optional accounts, optional paid features |

Items listed in "Later" are options, not commitments, and none may become a dependency of the offline core.

## Milestones (engineering, toward v1.0)

Full task lists live in [IMPLEMENTATION_PLAN](../development/IMPLEMENTATION_PLAN.md).

| Milestone | Outcome | Depends on |
|---|---|---|
| M0 | Environment ready (Flutter, JDK 17, Android SDK, phone visible to `adb`) | — |
| **M1** | **Native CameraX prototype inside Flutter on the physical phone** (first coding milestone) | M0 |
| S1-S3 | Spikes: recording path, segmentation runtime, surface/rotation approach | M1 |
| M2 | GL pipeline passthrough: camera → EGL render thread → Flutter texture, correct rotation/mirroring | M1, S3 |
| M3 | Segmentation mask live (overlay debug view) | M2, S2 |
| M4 | Cartoon shader + foreground/background compositing, 4 styles | M3 |
| M5 | Photo capture + MediaStore + DB index | M4 |
| M6 | Video recording with audio | M4, S1 |
| M7 | Gallery, settings, onboarding, permissions polish | M5, M6 |
| M8 | Performance, thermal, adaptive quality, soak | M6 |
| M9 | Hardening, acceptance run (AC-01…AC-18), release candidate | M7, M8 |

## Feature prioritization (MoSCoW for v1.0)

- **Must:** FR-01…FR-15, FR-17.
- **Should:** FR-16.
- **Could:** FR-18.
- **Won't (v1.0):** everything in PRD §8.

Prioritization rule: anything that does not directly support "stylized live preview → capture → keep" waits.

## Dependencies between roadmap items

- Mode B depends on: stable segmentation + render pipeline (v1.0), pose-model licensing review (OQ-08), character art pipeline (OQ-09), a background-reveal approach.
- Multiple people depend on: a multi-person segmentation model or instance segmentation (research; selfie models are single-subject [REF]).
- Animals depend on: animal detector/keypoint model with a commercially usable license (research; may require training data and custom training, which is out of budget until verified).
- iOS depends on: v1.0 shipping and stable bridge contract (`docs/integrations/API.md`); shared algorithm specs in [RENDERING_ENGINE](../architecture/RENDERING_ENGINE.md). Shaders are rewritten in Metal, not shared.

## Delivery criteria

| Release | Must hold |
|---|---|
| v1.0 | All AC-01…AC-18 pass on the reference device; Tier B device passes AC-12 with fallback; license/notice review done for every bundled library and model; release APK has no `INTERNET`; no open P0/P1 bugs |
| v1.1 | No regression of v1.0 ACs; new styles pass AC-07; performance not worse than v1.0 by > 10 % [EST] |
| v2.0 | Mode B ACs written first in PRD v2; pose model license cleared |
| v3.0 | Animal model licensing cleared and measured on device; iOS parity checklist |
