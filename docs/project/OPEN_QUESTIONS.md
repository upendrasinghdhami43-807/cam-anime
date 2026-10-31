# Open Questions

Status: Open · Blocking? (which milestone) · Owner · How to resolve.

## Needs the project owner

| ID | Question | Blocks | Resolve by |
|---|---|---|---|
| OQ-01 | Reference device: Xiaomi Redmi phone. Exact model, Android version, SoC, RAM, and GPU are not yet confirmed. | M0 (end), acceptance numbers | Connect the Redmi phone through USB and run the ADB diagnostic commands. Record the exact specifications in `PROJECT_STATUS.md`. |
| OQ-02 | Organization/package ID (default proposal `com.camanime.app`)? It cannot change after publishing. | M1 (`flutter create --org`) | Owner decision. |
| OQ-03 | Is the name "Cam-Anime" and its logo available/trademark-safe? App icon design? | Store release | Owner / legal check. |
| OQ-04 | Is minSdk 29 acceptable for the target market (ADR-011)? | M1 | Check Android market share in target countries. |
| OQ-05 | ABI policy: arm64-v8a only vs also armeabi-v7a. | M3 (runtime libraries) | Target-audience data; size trade-off. |
| OQ-07 | Is the classical cartoon look (cel/ink/pastel/noir shaders on a person mask) acceptable as "Mode A" for v1.0, rather than a learned anime redraw? | M4 | Owner reviews M4 visual output; ADR-012. |
| OQ-09 | Mode B: art style, who produces character art/rigs, budget? | v2.0 | Owner decision before v2.0 planning. |
| OQ-10 | How visible is segmentation-mask lag on the reference Redmi device, and what mitigations are enough? | M3 | Measure `maskAgeMs` and review test clips. |
| OQ-12 | Repository license and open-source/closed-source plan; third-party notice approach. | Before publishing | Owner decision. |
| OQ-15 | Is a 720p-class stylized photo acceptable, or is higher resolution needed in v1.0? | M5 | Owner review of M5 photos; v1.1 path exists. |
| OQ-17 | Legal/compliance review (privacy policy, children, regional rules). | Store release | Owner / counsel. |
| OQ-19 | Exact Redmi model and Android version. | M0 | Run `adb shell getprop` diagnostics. |
| OQ-20 | Is a second Android phone available for performance and compatibility testing? | M8 | Owner decision. |
| OQ-21 | Confirm whether the optional Docker development environment should include PostgreSQL and a backend API, or whether the MVP should remain entirely local without a backend. | Backend integration milestone, if approved | Owner decision. |

## Technical research (not performed yet)

| ID | Question | Blocks | Resolve by |
|---|---|---|---|
| OQ-06 | Which person-segmentation model has a confirmed commercially redistributable license and acceptable quality/speed? Models in MODEL_CATALOG are leads only. | M3 | Read model cards; spike S2. |
| OQ-08 | License and suitability of pose models for Mode B. | v2.0 | Model cards; license review. |
| OQ-11 | How to store model binaries in Git (LFS vs direct vs fetch script). | First model commit | Decide when first model is adopted; small files may be committed directly. |
| OQ-13 | Flutter texture API (`createSurfaceProducer` vs `createSurfaceTexture`), required Flutter version, EGL-on-producer-surface behavior, Impeller interaction. | M2 (S3) | Flutter docs/source + prototype on the phone. |
| OQ-14 | Can CameraX `CameraEffect` (preview + video) support our GL pipeline with the Flutter surface and asynchronous mask input at 720p30? | M6 (S1) | Prototype S1; ADR-006. |
| OQ-16 | Optimal mask/inference rate and input resolution trade-off. | M3/M8 | Measurements on Redmi device. |
| OQ-18 | Does JDK 17 + Flutter-generated Gradle/AGP work cleanly alongside system JDK 25 on Ubuntu? | M0 | `flutter doctor -v`, `./gradlew -version`. |

## Development environment — confirmed by owner

- Host development operating system: Ubuntu Linux (exact current version to be verified).
- Mobile development framework: Flutter.
- Android physical-device debugging: enabled on the Redmi phone.
- Android Developer Options: enabled.
- USB debugging: intended development workflow.
- Container platform: Docker installed on the laptop.
- Backend/database development: Docker can host optional local development services.
- Primary development workflow: write code on Ubuntu, build the Android application, install and debug it on the connected Redmi phone.

### Environment details still to verify

- Exact Redmi model.
- Android version and API level.
- Device RAM and available storage.
- Device CPU and GPU.
- Flutter version.
- Dart version.
- Java version used by Flutter/Gradle.
- Android SDK and Build Tools versions.
- ADB connection status.
- Docker Engine and Docker Compose versions.

## Backend and Docker architecture decision

Docker is a laptop-side development tool, not an Android application runtime.

Potential optional local development architecture:

```
Ubuntu laptop
|
|-- Flutter development environment
|-- Android SDK / ADB
|-- Docker Engine
|
|-- Optional backend API
|-- Optional PostgreSQL database
|-- Optional supporting services
|
|-- USB debugging
|
|-- Redmi Android phone
|
|-- Cam-Anime application
|-- Native CameraX
|-- On-device vision engine
|-- On-device cartoon rendering
|-- Local SQLite database
|-- Local photo/video storage
```

Important MVP rule:

The camera, transformation engine, photo capture, video recording, and local gallery must not depend on Docker, PostgreSQL, or a backend API.

If a local backend is introduced for development, the Android application can access it through the laptop's LAN IP address and an appropriate development network configuration.

Do not use `localhost` inside the Android application to refer to a backend running on the laptop. Android emulator networking and physical-device networking have different host-access rules.

## Decisions that require real-device testing

- Mask latency visibility (OQ-10 / M3): is 1–3 frames of lag objectionable?
- GPU vs CPU inference while rendering (S2).
- Recording path A vs B (S1) and audio/video offset compensation.
- Whether front-camera quality needs different smoothing/mask parameters.
- Thermal thresholds and recovery timing (M8).
- Orientation behavior on the Redmi phone.
- Flash behavior for rear-camera photo capture.
- Camera compatibility and supported resolutions.
- Sustained preview FPS and battery consumption.

## Added/closed log

- 2026-10-31: Initial open questions created.
- 2026-10-31: Owner confirmed Redmi Android phone, Flutter development, Android Developer Options, and Docker availability on the development laptop.
- 2026-10-31: OQ-01 partially resolved; exact phone specifications pending.
- 2026-10-31: Development workflow established as Ubuntu laptop + Flutter + physical Redmi Android device.
- 2026-10-31: Docker classified as an optional laptop-side development environment, not a core Android runtime dependency.
