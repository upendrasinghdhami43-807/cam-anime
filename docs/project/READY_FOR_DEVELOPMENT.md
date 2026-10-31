# Ready for Development — Readiness Audit

Date: 2026-10-31 · Auditor: planning agent · Scope: documentation and repository foundation (no application code exists by design).

Status vocabulary: **COMPLETE** · **PARTIALLY COMPLETE** · **PENDING** · **REQUIRES REAL-DEVICE VALIDATION**.

## 1. Readiness checklist

| # | Item | Status | Evidence / caveat |
|---|---|---|---|
| 1 | Product definition | COMPLETE | [PRD](../product/PRD.md), [ROADMAP](../product/ROADMAP.md), [USER_FLOWS](../product/USER_FLOWS.md), [FEATURE_SPECIFICATIONS](../product/FEATURE_SPECIFICATIONS.md); MVP boundary fixed (v1.0/1.1/2.0/3.0). Owner has not yet reviewed/approved it |
| 2 | Architecture defined | COMPLETE (with 2 gated decisions) | [ARCHITECTURE](../architecture/ARCHITECTURE.md); ADR-005 (segmentation runtime) and ADR-006 (recording path) are **Proposed**, decided by spikes S2/S1 |
| 3 | Technology stack selected | PARTIALLY COMPLETE | UI, state, DB, camera, rendering selected; ML runtime and recording path pending spikes; package versions deliberately not pinned until M1 |
| 4 | Repository structure defined | COMPLETE | [PROJECT_STRUCTURE](../architecture/PROJECT_STRUCTURE.md); Flutter project is created in M1 (not faked now) |
| 5 | Database design documented | COMPLETE | [DATABASE](../data/DATABASE.md): 2 MVP tables. Migration tooling commands to confirm at M5/M7 |
| 6 | Camera pipeline documented | COMPLETE on paper; REQUIRES REAL-DEVICE VALIDATION | [CAMERA_PIPELINE](../architecture/CAMERA_PIPELINE.md); API names are recalled from memory and need doc confirmation |
| 7 | AI/ML research requirements documented | COMPLETE (requirements) / PENDING (research) | [AI_AND_COMPUTER_VISION](../architecture/AI_AND_COMPUTER_VISION.md), [MODEL_CATALOG](../models/MODEL_CATALOG.md): **no model license verified**, no benchmarks |
| 8 | Security and privacy documented | COMPLETE | [SECURITY](../security/SECURITY.md), [STORAGE_AND_PRIVACY](../data/STORAGE_AND_PRIVACY.md); legal review PENDING (OQ-17) |
| 9 | Testing strategy documented | COMPLETE | [TESTING](../development/TESTING.md); every AC-01…AC-18 mapped |
| 10 | Development setup documented | COMPLETE; environment itself PENDING | [DEVELOPMENT_SETUP](../development/DEVELOPMENT_SETUP.md); Flutter, JDK 17, Android SDK, Android Studio, phone all **missing** [ENV] |
| 11 | Implementation roadmap complete | COMPLETE | [IMPLEMENTATION_PLAN](../development/IMPLEMENTATION_PLAN.md) M0-M9 + spikes |
| 12 | Open technical questions listed | COMPLETE | [OPEN_QUESTIONS](OPEN_QUESTIONS.md) (OQ-01…OQ-18) |
| 13 | First coding milestone defined | COMPLETE | M1 with 15 ordered tasks and 11 acceptance criteria in IMPLEMENTATION_PLAN |

## 2. Consistency audit results (Phase 3)

| Check | Result |
|---|---|
| All required files exist | Pass (scripted check) |
| Internal Markdown links and anchors resolve | Pass (scripted check) |
| OQ/ADR/AC/FR/NFR/screen IDs referenced are defined | Pass (scripted check) |
| Every AC mapped to a test or manual check | Pass |
| PRD ↔ Roadmap scope agree | Pass (v1.0 = FR-01…18; Mode B v2.0; animals/iOS v3.0) |
| Architecture ↔ structure ↔ AGENTS agree | Pass (one Android library module, no OpenCV/C++, Riverpod/go_router/Drift) |
| Database ↔ MVP features | Pass (`media_items`, `app_settings`; settings keys cover FR-13) |
| Bridge contract ↔ features/milestones | Pass (API.md milestones match IMPLEMENTATION_PLAN) |
| No paid service required for MVP | Pass (no backend, no paid APIs) |
| Offline operation possible | Pass by design (no INTERNET; bundled models); **not yet verifiable** |
| iOS plan does not interfere with Android MVP | Pass (iOS only in ARCHITECTURE §8; Dart contract platform-neutral; no iOS work scheduled before v3.0) |
| Scope realism | Medium risk: solo developer; mitigated by fixed MVP boundary and spikes |

Fixes made during the audit: S-06 style selector made consistent between USER_FLOWS and SCREEN_SPECIFICATIONS (inline rail); `effect_off` tier added to API events; OQ-10 added to the table; `third_party/licenses` added to the structure.

## 3. Verified vs unverified

- **Verified [ENV]:** machine inventory; `scripts/check_env.sh` runs; JDK 17 and Flutter snap are available via package managers.
- **Not verified [REF]:** every external version number (Flutter, Dart, CameraX, LiteRT) and every model/library license. Official documentation pages could not be fetched during planning; version numbers came from a secondary web summary and are **not pinned anywhere** in the docs by design.
- **Not measured [EST]:** all performance numbers.
- **Not validated on a device:** everything camera-related.

## 4. Blockers before M1 coding

1. Install Flutter, JDK 17, Android Studio + SDK; authorize the phone (M0).
2. Answer OQ-02 (package id) and OQ-01 (device).
3. Owner review of the PRD/roadmap/architecture trade-offs below.

## 5. Decisions where the plan deliberately differs from the brief

| Brief | Plan | Why |
|---|---|---|
| C++ and OpenCV in the stack | Deferred (ADR-004) | GPU shaders cover MVP needs; avoids NDK/JNI/size cost |
| 6 DB entities | 2 tables (ADR-015) | Others are static catalogs or post-MVP |
| 4 engine directories | 1 Android library module (ADR-010) | Same boundaries, less premature modularity |
| "Human detection" as a stage | Derived from segmentation | One fewer model/inference per frame |
| Mode A "preserves identity" with cartoon filters | Hue-preserving classical stylization | Honest scope: filter look, not a learned redraw (OQ-07) |
| Mode B "replace the person" | v2.0 | Background reveal and art pipeline are unsolved and costly |

## 6. First coding milestone

**M1 — Build and run the first native Android CameraX prototype inside the Flutter application** on the physical phone: no cartoon, GL, or ML. Exact criteria: [IMPLEMENTATION_PLAN §M1](../development/IMPLEMENTATION_PLAN.md#m1--first-coding-milestone-native-camerax-prototype-inside-flutter-).

## 7. Overall verdict

**Documentation foundation: COMPLETE. Project ready to begin M0 (environment) immediately; ready for M1 coding once M0 is done and OQ-01/OQ-02 are answered.** Technical feasibility of the full pipeline (Flutter texture + GL + segmentation + recording at 720p30) is **PENDING real-device validation** and is intentionally staged through M1 → S3 → M2 → S2/M3 → S1/M6 so that each unknown is retired before the next depends on it.
