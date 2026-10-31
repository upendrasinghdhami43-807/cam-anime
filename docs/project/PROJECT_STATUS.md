# Project Status

Last updated: 2026-10-31 · Phase: **Planning complete → awaiting M0 (environment setup)** · Current milestone: **M0**, next coding milestone: **M1**.

## Environment snapshot [ENV]

| Item | Value |
|---|---|
| OS | Ubuntu 26.04.1 LTS x86_64, 12 cores, 14 GiB RAM, 201 GiB free |
| Git | 2.53.0 (repository **not yet initialized**) |
| JDK | OpenJDK 25 (`/usr/lib/jvm/java-25-openjdk-amd64`); OpenJDK 17 verified present at `/usr/lib/jvm/java-17-openjdk-amd64` |
| Flutter / Dart | not installed |
| Android SDK / adb / Android Studio | not installed |
| Docker | Docker Engine 29.9.2, Docker Compose v5.6.1 present on host |
| CMake / Ninja / clang | present (not needed for the MVP) |
| Reference phone | Xiaomi Redmi phone confirmed by owner; exact model, Android version, SoC, RAM, and GPU pending USB connection & ADB diagnostics (OQ-01, OQ-19) |

## Completed work

- Product definition: PRD, roadmap, user flows, feature specifications.
- Architecture: system architecture, project structure, camera pipeline, AI/CV strategy, rendering engine, ADR-001…016.
- Data and integration: database design, storage/privacy, integrations, bridge contract.
- UX: design system, screen specifications.
- Process: AGENTS.md, setup, implementation plan, coding standards, workflow, testing, debugging, build/release.
- Quality: security model, performance plan, model catalog and asset management.
- Tooling: `scripts/check_env.sh` (tested, read-only).

## Pending work (by milestone)

| Milestone | Status |
|---|---|
| M0 environment | PENDING — needs Flutter, Android SDK, phone (JDK 17 verified installed) |
| M1 CameraX in Flutter | PENDING — REQUIRES REAL-DEVICE VALIDATION |
| S3, S2, S1 spikes | PENDING |
| M2-M9 | PENDING |

## Research status

| Item | Status |
|---|---|
| Model licenses and model cards | PENDING (no model verified; leads only) |
| Official docs verification of CameraX/Flutter/MediaPipe/LiteRT versions and APIs | PARTIALLY COMPLETE — version numbers came from a secondary web summary [REF]; direct fetches of official pages were not possible during planning |
| Device performance | REQUIRES REAL-DEVICE VALIDATION (nothing measured) |

## Known risks

| ID | Risk | Mitigation |
|---|---|---|
| R-01 | Flutter texture ↔ CameraX/EGL surface behavior (rotation, pacing, resize) unproven | M1 simple path, spike S3 before M2 |
| R-02 | Segmentation latency and quality; mask lag on motion | S2, M3 measurements, staleness fade, v1.1 refinement |
| R-03 | Recording stylized frames with synced audio | S1 two-path plan |
| R-04 | Mid/low-end device performance and heat | Quality tiers, thermal controller, Tier B acceptance |
| R-05 | Model licensing blocks bundling | Licensing gate; alternative models; matting fallback |
| R-06 | Classical cartoon look may disappoint | OQ-07 early visual review at M4 |
| R-07 | JDK/Gradle toolchain mismatch on Ubuntu 26.04 | JDK 17 + `flutter config --jdk-dir` (ADR-016) |
| R-08 | Solo-developer scope creep (Mode B, animals) | Fixed roadmap; AGENTS scope rules |
| R-09 | OEM camera/codec quirks | Capability probing, fallback paths, device checklists |

## Next milestone

**M0 → M1.** Exact steps: `docs/development/IMPLEMENTATION_PLAN.md`.

## Test run log

| Date | Commit | Device | Suite | Result |
|---|---|---|---|---|
| – | – | – | – | No tests exist yet |
