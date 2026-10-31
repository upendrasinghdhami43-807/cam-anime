# Changelog

Format: [Keep a Changelog](https://keepachangelog.com/) style; versions follow [BUILD_AND_RELEASE §4](../development/BUILD_AND_RELEASE.md). Documentation-only changes are logged under "Project" until the first app release.

## [Unreleased]

### Project
- 2026-10-31: Planning phase. Created the complete documentation set (product, architecture, data, integrations, design, development, security, performance, models, project), `AGENTS.md`, `README.md`, `.gitignore`, and `scripts/check_env.sh`.
- Architecture decisions recorded as ADR-001…ADR-016 (Proposed: ADR-005 segmentation runtime, ADR-006 recording path).
- Environment inspected: Flutter, Android SDK, adb, Android Studio missing; JDK 25 only; no phone connected.

### Architectural changes
- Deviated from the initial repository proposal: single Flutter package + one Android library module instead of four engine directories; per-feature layers instead of top-level `data/domain/services`; only two MVP database tables; no OpenCV/C++ in MVP (see PROJECT_STRUCTURE §2, DATABASE §1, ADR-004, ADR-010, ADR-015).

### Features
- None yet (no application code exists).
