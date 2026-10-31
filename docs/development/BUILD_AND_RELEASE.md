# Build and Release

Official references: [Flutter Android deployment](https://docs.flutter.dev/deployment/android), [Android app signing](https://developer.android.com/studio/publish/app-signing), [Play App Signing](https://support.google.com/googleplay/android-developer/answer/9842756). Verify exact current requirements (target API level policy, bundle format) before the first store submission [REF].

## 1. Build modes

| Mode | Command (in `apps/mobile`) | Use |
|---|---|---|
| Debug | `flutter run` / `flutter build apk --debug` | Development; hot reload; **never** for performance numbers |
| Profile | `flutter run --profile` | Performance measurement (AOT, profiling hooks) |
| Release | `flutter build apk --release` / `flutter build appbundle --release` | Acceptance tests and distribution |

Engine module tests: `(cd android && ./gradlew :camanime_engine:testDebugUnitTest)`; instrumented: `./gradlew :camanime_engine:connectedDebugAndroidTest` (phone attached).

## 2. APK vs App Bundle

- **APK** (`build/app/outputs/flutter-apk/app-release.apk`): sideloading and local acceptance testing; use `--split-per-abi` to reduce size (`app-arm64-v8a-release.apk` for modern phones).
- **AAB** (`build/app/outputs/bundle/release/app-release.aab`): required for Play Store distribution [REF]; Play generates per-device APKs.
- ABI policy: `arm64-v8a` primary; add `armeabi-v7a` only if OQ-05 says the audience needs it (affects APK size and ML runtime `.so` count).

## 3. Signing

- Debug builds are signed with the auto-generated debug key.
- Release: create an upload keystore **outside the repo** (e.g., `~/keys/camanime-upload.jks`) with `keytool`; reference it via `apps/mobile/android/key.properties` (git-ignored) read in `app/build.gradle(.kts)`. Back up the keystore and passwords in a password manager; losing the upload key is recoverable with Play App Signing only via Google support. Never commit `*.jks`, `key.properties`.
- Use **Play App Signing** when publishing (Google holds the app signing key; you keep the upload key) [REF].

## 4. Versioning

- `pubspec.yaml` `version: MAJOR.MINOR.PATCH+BUILD` (maps to `versionName`/`versionCode`). `BUILD` increases on every uploaded build.
- Semantic meaning: MAJOR = product generation (v2 = Mode B), MINOR = features, PATCH = fixes. v1.0.0 = MVP.
- Engine `engineVersion` (stored in `media_items.engine_version`) = app version + git short hash from a build step.
- Tag releases `vX.Y.Z`; update [CHANGELOG](../project/CHANGELOG.md).

## 5. Release configuration checklist

- [ ] `INTERNET` absent from the **merged release manifest** (`aapt2 dump permissions app-release.apk`; script `scripts/verify_no_internet.sh`, M8)
- [ ] `android:allowBackup="false"`; data extraction rules exclude DB
- [ ] `minSdk 29`; `targetSdk` = current Play requirement [REF]
- [ ] Shrinking/obfuscation: R8 on for release; ProGuard keep rules for the ML runtime and JNI as the runtime's docs require; Dart `--obfuscate --split-debug-info` optional (store symbols outside repo)
- [ ] Models present in the APK with matching SHA-256 manifest
- [ ] Debug overlay hidden/gated; no debug logging of media paths
- [ ] App label, icon, adaptive icon, splash
- [ ] Third-party licenses compiled (Flutter licenses + native libs + models)

## 6. Release validation

1. Build release APK; install on the reference phone **by `adb install`** (not `flutter run`).
2. Run the MVP acceptance suite (TESTING §10) on the release build.
3. Check size (NFR-05), start time (NFR-03), memory (NFR-04) in release.
4. Run `flutter analyze`, `flutter test`, Kotlin tests, instrumented tests on the phone.
5. Confirm airplane-mode walkthrough.
6. Update PROJECT_STATUS with the results; tag only after the owner approves.

## 7. Future Play Store preparation (post-MVP)

Developer account, store listing assets, content rating questionnaire, data safety form (declare: no data collected; camera/microphone used on-device only), privacy policy URL (required for camera/microphone apps [REF]), target-API compliance, internal testing track → closed → production, crash/ANR monitoring via Play Console vitals (no SDK required), 16 KB page-size compatibility for native libraries if targeting recent Android requirements [REF, check ML runtime `.so` alignment].
