# Cam-Anime

AI-powered, real-time cartoon camera for Android (iOS later). Point the camera at a person and see them rendered as a cartoon **live**, with the real-world background left untouched. Take photos, record videos with original microphone audio, and keep everything on the device.

> **Status: planning complete, no application code yet.** The repository currently contains the product, architecture and process documentation. The first coding milestone (M1) is a native CameraX preview inside a Flutter app. See [docs/project/READY_FOR_DEVELOPMENT.md](docs/project/READY_FOR_DEVELOPMENT.md) and [docs/project/PROJECT_STATUS.md](docs/project/PROJECT_STATUS.md).

## Principles

Offline-first · on-device inference · no mandatory backend · no paid AI APIs · privacy-first · modular · performance- and battery-aware.

## MVP (v1.0) at a glance

- Live camera (rear/front, flash, zoom), 720p target at 24-30 FPS.
- **Mode A:** cartoon stylization of one human subject (foreground segmentation + GPU shader), real background preserved.
- 4 cartoon styles, photo capture, video recording with microphone audio, in-app gallery, settings, onboarding.
- Fully offline. The release build declares no `INTERNET` permission.

Not in the MVP: character replacement (Mode B), animals, multiple people, cloud, accounts, iOS. See [ROADMAP](docs/product/ROADMAP.md).

## Architecture summary

```
Flutter UI (Dart)  --MethodChannel/EventChannel (control only)-->  Native Android engine (Kotlin)
      ^                                                              CameraX -> GL ES render thread
      |                                                              (segmentation mask + cartoon shader + compositing)
      +----------------- Texture(textureId): zero-copy preview <-----+-> Photo (MediaStore) / Video (MediaCodec/CameraX)
```

Camera frames never cross into Dart. Details: [ARCHITECTURE](docs/architecture/ARCHITECTURE.md), [CAMERA_PIPELINE](docs/architecture/CAMERA_PIPELINE.md).

## Prerequisites

Ubuntu Linux, Git, Flutter (stable, bundles Dart), **JDK 17**, Android Studio + Android SDK (platform-tools, build-tools, platform, NDK/CMake only when native C++ is introduced), and a physical Android phone with USB debugging. Nothing here is installed yet except Git, CMake, Ninja and JDK 25 (not suitable for Gradle; see setup guide).

Check your machine first (read-only, installs nothing):

```bash
./scripts/check_env.sh
```

Then follow [docs/development/DEVELOPMENT_SETUP.md](docs/development/DEVELOPMENT_SETUP.md).

## Run / build / test

The Flutter project does not exist yet. It is created in milestone M1 at `apps/mobile`. After M1:

```bash
cd apps/mobile
flutter pub get
flutter devices                 # the phone must be listed
flutter run                     # debug on the connected phone
flutter run --profile           # use this for any performance judgement
flutter build apk --release     # see docs/development/BUILD_AND_RELEASE.md
flutter analyze && flutter test
(cd android && ./gradlew :camanime_engine:testDebugUnitTest)
```

Details: [BUILD_AND_RELEASE](docs/development/BUILD_AND_RELEASE.md), [TESTING](docs/development/TESTING.md).

## Documentation index

| Area | Documents |
|---|---|
| Product | [PRD](docs/product/PRD.md) · [ROADMAP](docs/product/ROADMAP.md) · [USER_FLOWS](docs/product/USER_FLOWS.md) · [FEATURE_SPECIFICATIONS](docs/product/FEATURE_SPECIFICATIONS.md) |
| Architecture | [ARCHITECTURE](docs/architecture/ARCHITECTURE.md) · [PROJECT_STRUCTURE](docs/architecture/PROJECT_STRUCTURE.md) · [CAMERA_PIPELINE](docs/architecture/CAMERA_PIPELINE.md) · [AI_AND_COMPUTER_VISION](docs/architecture/AI_AND_COMPUTER_VISION.md) · [RENDERING_ENGINE](docs/architecture/RENDERING_ENGINE.md) · [TECHNICAL_DECISIONS](docs/architecture/TECHNICAL_DECISIONS.md) |
| Data | [DATABASE](docs/data/DATABASE.md) · [STORAGE_AND_PRIVACY](docs/data/STORAGE_AND_PRIVACY.md) |
| Integration | [INTEGRATIONS](docs/integrations/INTEGRATIONS.md) · [API](docs/integrations/API.md) |
| Design | [DESIGN](docs/design/DESIGN.md) · [SCREEN_SPECIFICATIONS](docs/design/SCREEN_SPECIFICATIONS.md) |
| Development | [DEVELOPMENT_SETUP](docs/development/DEVELOPMENT_SETUP.md) · [IMPLEMENTATION_PLAN](docs/development/IMPLEMENTATION_PLAN.md) · [CODING_STANDARDS](docs/development/CODING_STANDARDS.md) · [FEATURE_DEVELOPMENT_WORKFLOW](docs/development/FEATURE_DEVELOPMENT_WORKFLOW.md) · [TESTING](docs/development/TESTING.md) · [DEBUGGING](docs/development/DEBUGGING.md) · [BUILD_AND_RELEASE](docs/development/BUILD_AND_RELEASE.md) |
| Quality | [SECURITY](docs/security/SECURITY.md) · [PERFORMANCE](docs/performance/PERFORMANCE.md) |
| Models | [MODEL_CATALOG](docs/models/MODEL_CATALOG.md) · [MODEL_ASSET_MANAGEMENT](docs/models/MODEL_ASSET_MANAGEMENT.md) |
| Project | [PROJECT_STATUS](docs/project/PROJECT_STATUS.md) · [OPEN_QUESTIONS](docs/project/OPEN_QUESTIONS.md) · [GLOSSARY](docs/project/GLOSSARY.md) · [CHANGELOG](docs/project/CHANGELOG.md) · [READY_FOR_DEVELOPMENT](docs/project/READY_FOR_DEVELOPMENT.md) |
| AI agents | [AGENTS.md](AGENTS.md) |

## Evidence labels used in the docs

Every technical claim that depends on the outside world is tagged so it can be trusted appropriately:

| Tag | Meaning |
|---|---|
| **[ENV]** | Observed on this machine by running a command. |
| **[REF]** | Reported by a secondary source or recalled from documentation; **not yet confirmed against the linked official page**. Re-verify before relying on it. |
| **[REC]** | Engineering recommendation / decision made in these docs. |
| **[EST]** | Estimate. Not measured. |
| **[OPEN]** | Unresolved; tracked in [OPEN_QUESTIONS](docs/project/OPEN_QUESTIONS.md). |

No benchmark number in this repository is a measurement unless it sits in a file under `docs/performance/results/` with a device name and commit hash.

## License

Not yet chosen (tracked as OQ-12). Do not publish the repository before a license and third-party notices are decided.
