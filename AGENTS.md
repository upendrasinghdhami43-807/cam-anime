# AGENTS.md — Rules for all AI coding agents working on Cam-Anime

These rules are mandatory. If a rule blocks the task, stop and ask the user; do not work around it.

## 1. Project in one paragraph

Cam-Anime is an offline, on-device, real-time cartoon camera. UI is Flutter/Dart (`apps/mobile`). The camera, GPU rendering, ML inference and recording run in a **native Android engine** written in Kotlin (library module `camanime_engine`). Camera frames never enter Dart. Preview reaches Flutter through a `Texture`. See `docs/architecture/ARCHITECTURE.md`.

## 2. Mandatory session workflow

1. Inspect the repository (`git status`, tree, existing code) before anything else.
2. Read this file.
3. Read the documents relevant to the task (see §3).
4. Identify the current milestone in `docs/project/PROJECT_STATUS.md` and `docs/development/IMPLEMENTATION_PLAN.md`. Work only on that milestone unless told otherwise.
5. Inspect existing source in the area you will touch.
6. Explain the proposed change (files, approach, risks) **before** editing.
7. Implement only the required scope.
8. Run formatters/analyzers (`dart format`, `flutter analyze`, Kotlin lint/ktlint if configured).
9. Run relevant tests.
10. Check the build still compiles (`flutter build apk --debug` at minimum when native code changed).
11. Report changed files.
12. Report the exact commands executed.
13. Report verification results, including failures. Never claim a build, test, or device run passed unless you executed it in this session. If something could not be run (no phone attached, no SDK), say so.
14. Update `docs/project/PROJECT_STATUS.md` (and other affected docs, `docs/project/CHANGELOG.md`).

## 3. Which documents to read

| Task touches | Read |
|---|---|
| Any feature | `docs/product/PRD.md`, `docs/product/FEATURE_SPECIFICATIONS.md`, `docs/development/FEATURE_DEVELOPMENT_WORKFLOW.md` |
| Camera / frames / threads | `docs/architecture/CAMERA_PIPELINE.md`, `docs/integrations/API.md` |
| Shaders / stylization | `docs/architecture/RENDERING_ENGINE.md` |
| ML models / inference | `docs/architecture/AI_AND_COMPUTER_VISION.md`, `docs/models/*` |
| Files placement | `docs/architecture/PROJECT_STRUCTURE.md` |
| Database / storage | `docs/data/DATABASE.md`, `docs/data/STORAGE_AND_PRIVACY.md` |
| UI | `docs/design/DESIGN.md`, `docs/design/SCREEN_SPECIFICATIONS.md` |
| Dependencies / permissions | `docs/architecture/TECHNICAL_DECISIONS.md`, `docs/security/SECURITY.md` |
| Tests | `docs/development/TESTING.md` |

## 3a. Evidence labels

Docs tag facts as **[ENV] [REF] [REC] [EST] [OPEN]** (see `README.md`). Treat **[REF]** as unconfirmed. When you rely on one, confirm it in the official documentation first and update the tag.

## 4. Architecture constraints (do not change without an ADR and user approval)

- **No camera frames in Dart.** Flutter gets a `Texture` id and control/event messages only. No `EventChannel`/`MethodChannel` payload may carry pixel data. Small results (FPS numbers, state enums, a thumbnail path) are fine.
- **Flutter ↔ native**: MethodChannel for commands, EventChannel for streamed state. The contract lives in `docs/integrations/API.md`; change the doc and both sides in the same change.
- **Camera work is never on the main thread.** Dedicated executors/threads: camera callbacks, GL render thread, inference thread, encoder threads. Frame queues are bounded; stale frames are dropped, never queued without limit.
- **Offline.** No `INTERNET` permission in release builds. No network code, analytics, crash reporters, ad SDKs, or remote config in the MVP.
- **Rendering**: OpenGL ES 3.0 on Android for the MVP. No Vulkan, OpenCV, or custom C++ until an ADR approves it with a profiling justification.
- **Layering**: Flutter `presentation → domain → data`; native `bridge → engine components`. UI code must not know about CameraX; engine code must not know about Flutter widgets.
- **Directory rules**: put code where `docs/architecture/PROJECT_STRUCTURE.md` says. Do not create top-level directories, new Gradle modules, or new Dart packages on your own.
- **State management**: Riverpod. Navigation: go_router. Database: Drift. Do not add alternatives.
- Mode B (character replacement), animals, iOS and cloud features are **out of MVP scope**. Do not add scaffolding, stubs, or placeholder UI for them beyond what the docs specify.

## 5. Coding standards (summary — full text in `docs/development/CODING_STANDARDS.md`)

- Dart: `flutter_lints` + project `analysis_options.yaml`; no `dynamic` without comment; no `print` (use the logger); immutable models; `const` where possible; files `snake_case.dart`.
- Kotlin: official Kotlin style; no `!!` in production code; coroutines or explicit executors, never raw unmanaged threads; every acquired camera/GL/codec resource has a single owner and a documented release point.
- GLSL: shaders live as files in the engine module assets; no string-built shaders; uniforms documented in the shader header.
- Comments only where intent is non-obvious. Public engine APIs get KDoc.
- Errors: typed errors that cross the bridge carry a stable code from `docs/integrations/API.md`. Never swallow exceptions silently.

## 6. Dependency rules

- Do not add, remove, or upgrade a dependency without a stated reason in the task and user approval for anything beyond a patch bump.
- Before adding one: check license (commercial use, redistribution), maintenance status, size, Android compatibility, and whether it needs network access. Record it in `docs/architecture/TECHNICAL_DECISIONS.md` (or the model catalog for models).
- Do not invent package versions. Obtain them with `flutter pub add` / the Gradle version catalog from the official repository, and let `pubspec.lock` pin them. Commit lock files.
- Never "fix" a build by deleting the lockfile, disabling lint, or downgrading the toolchain without telling the user.

## 7. API and library accuracy

- Never invent library APIs. If unsure, read the official documentation (links are in the docs) or the library source, and say what you checked.
- If official documentation cannot be reached, state that explicitly and mark the code/doc as unverified.

## 8. Testing requirements

- New logic ships with tests at the lowest layer that can prove it (Dart unit, widget, Kotlin unit). Bug fixes ship with a regression test when feasible.
- Camera, GL, and encoder behavior cannot be proven by unit tests: add or update the matching manual device checklist item in `docs/development/TESTING.md` and mark it "REQUIRES REAL-DEVICE VALIDATION" in `docs/project/PROJECT_STATUS.md` until the user confirms on a phone.
- A task is complete only when its acceptance criteria (PRD `AC-*` IDs) are verified. Do not mark a task done on "it compiles".
- Performance claims need a measurement (method in `docs/performance/PERFORMANCE.md`), recorded with device, build mode (profile/release), and commit hash. Debug builds are never used for performance numbers.

## 9. Security and privacy requirements

- Never hardcode secrets; never commit keystores, `key.properties`, or `.env` files.
- Never send camera frames, audio, photos, videos, or model inputs/outputs to any external server.
- Camera permission only on entering the camera flow; microphone only when recording starts. No hidden capture. Camera is released when the app is backgrounded.
- Load models only from the app's bundled assets (MVP) and verify checksums per `docs/models/MODEL_ASSET_MANAGEMENT.md`.
- Log no pixel data, no file contents, and no user media paths beyond what the debugging doc allows.

## 10. Git rules

- Never rewrite history, force-push, or delete branches/files the user did not ask you to. Ask before any destructive operation (deleting directories, `git reset --hard`, mass renames, dependency major bumps).
- Small, reviewable commits. Conventional style: `type(scope): summary` (types: feat, fix, docs, refactor, test, build, chore, perf). One concern per commit.
- Do not commit generated build output, `local.properties`, or signing files (see `.gitignore`).
- Commit only when the user asks you to, unless the task states otherwise.
- Include the trailer `Co-authored-by: Copilot <223556219+Copilot@users.noreply.github.com>` on commits created by an agent that is GitHub Copilot.

## 11. Scope discipline

- No unrelated refactoring, renaming, or reformatting. No drive-by dependency changes.
- Do not duplicate functionality that already exists; search first.
- Do not silently remove existing behavior. If removal is needed, say so and get approval.
- Explain trade-offs before any major architectural change, and write an ADR in `docs/architecture/TECHNICAL_DECISIONS.md`.
- Do not generate fake, stubbed, or non-functional code just to make the repo look complete.

## 12. Final report template (use at the end of every task)

```
Milestone/task:
Changed files:
Commands run:
Results (pass/fail, with output summary):
Not verified / requires real device:
Docs updated:
Follow-ups / risks:
```
