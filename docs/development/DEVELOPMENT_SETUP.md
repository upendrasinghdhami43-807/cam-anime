# Development Setup (Ubuntu)

Principle: **inspect first, install only what is missing, never reinstall working software.** Do not paste install commands blindly; run the diagnostics, compare with the table, and install only the rows marked MISSING.

## 1. Inspect (run this first and share the output)

```bash
./scripts/check_env.sh            # read-only; installs/changes nothing
```

## 2. Baseline observed on the project machine (2026-10-31)

| Item | Status | Source |
|---|---|---|
| OS | Ubuntu 26.04.1 LTS, x86_64, 12 cores, 14 GiB RAM (≈6 GiB free at the time), 201 GiB free disk | [ENV] |
| Git 2.53.0, curl, unzip, xz, CMake 4.2.3, Ninja 1.13.2, clang 21.1.8 | present | [ENV] |
| JDK | **only OpenJDK 25** (`/usr/lib/jvm/java-25-openjdk-amd64`) | [ENV] |
| Flutter / Dart | **missing** | [ENV] |
| Android SDK, `adb`, `sdkmanager`, Android Studio | **missing** (`ANDROID_HOME` unset, no `~/Android`, `~/.android`) | [ENV] |
| Android phone on USB | **not detected** (`lsusb` shows only a webcam and Bluetooth) | [ENV] |
| User groups | `plugdev` present (helps USB access) | [ENV] |
| `openjdk-17-jdk` | available from the Ubuntu archive (`17.0.20.1+1-1~26.04`) | [ENV] |
| `flutter` snap | available, publisher "Flutter Team" | [ENV] |
| `android-studio` snap | available but published by Snapcrafters (community), not Google | [ENV] |

Conflicts / risks: (1) JDK 25 is probably newer than the Gradle/AGP versions Flutter currently generates; use JDK 17 for Android builds [REC, ADR-016; verify with `flutter doctor -v`]. (2) RAM is tight when running Android Studio + Gradle + Flutter simultaneously; limit Gradle daemon memory (§8). (3) The phone is not yet connected/authorized.

## 3. Required components

| Component | Needed for | How to check | Install guidance |
|---|---|---|---|
| Git | Source control | `git --version` | present |
| Flutter SDK (includes Dart) | App | `flutter --version`, `dart --version` | §4 |
| JDK 17 | Gradle/AGP builds | `/usr/lib/jvm/*17*` | `sudo apt install openjdk-17-jdk` (keep JDK 25; don't change the system default) |
| Android Studio | SDK Manager, device tools, profiler, logcat UI | launch it | §5 |
| Android SDK: Platform-Tools (adb), a recent Platform, Build-Tools, Command-line Tools | Build/deploy | `adb version`, SDK Manager | via Android Studio SDK Manager (§5) |
| NDK + CMake (SDK) | **Only when native C++ is introduced** (not in the MVP) | SDK Manager | Skip for now |
| CMake/Ninja system packages | Not needed for Android builds (SDK ships its own CMake) | – | Leave as is |
| Chrome/Linux desktop toolchain | Not needed | – | Ignore `flutter doctor` warnings for them |

## 4. Flutter SDK

Follow the official guide first: <https://docs.flutter.dev/install/manual> (Linux). Two acceptable routes:

- **Git/tarball (recommended, transparent):**
  ```bash
  mkdir -p ~/development && cd ~/development
  git clone https://github.com/flutter/flutter.git -b stable
  echo 'export PATH="$HOME/development/flutter/bin:$PATH"' >> ~/.bashrc   # or ~/.zshrc
  source ~/.bashrc
  flutter --version     # downloads the matching Dart SDK on first run
  ```
- **Snap:** `sudo snap install flutter --classic` (official publisher per snap info [ENV]).

A secondary source reported the stable release as Flutter 3.47.x / Dart 3.13.x on 2026-10-23 [REF, unverified]. Do **not** pin from this document: install `stable`, record the exact output of `flutter --version` in `docs/project/PROJECT_STATUS.md` at M0.

Then: `flutter config --no-analytics` (optional), `flutter config --jdk-dir /usr/lib/jvm/java-17-openjdk-amd64`.

## 5. Android Studio and SDK

1. Download Android Studio from <https://developer.android.com/studio> (official tarball), extract to `~/android-studio`, run `bin/studio.sh`. (Snap is community-published; prefer the official download.)
2. First-run wizard: install the SDK to `~/Android/Sdk`.
3. SDK Manager → SDK Platforms: latest stable Android API level; SDK Tools: *Android SDK Build-Tools*, *Platform-Tools*, *Command-line Tools (latest)*, *Android Emulator* (optional; the project is tested on the physical phone).
4. Accept licenses: `flutter doctor --android-licenses`.
5. Environment variables (add to `~/.bashrc`):
   ```bash
   export ANDROID_HOME="$HOME/Android/Sdk"
   export PATH="$PATH:$ANDROID_HOME/platform-tools:$ANDROID_HOME/cmdline-tools/latest/bin"
   ```
   `ANDROID_SDK_ROOT` is deprecated in favor of `ANDROID_HOME` [REF].
6. Gradle is provided by the Gradle wrapper in the Flutter project; do not install Gradle system-wide.

## 6. Physical Android device

1. On the phone: Settings → About phone → tap *Build number* 7 times → Developer options → enable **USB debugging**. (Optional: *Disable adb authorization timeout*, *Stay awake*.)
2. Connect via a data-capable USB cable; choose "File transfer/Android Auto" mode if the phone asks.
3. Accept the "Allow USB debugging?" RSA prompt on the phone.
4. Verify:
   ```bash
   adb kill-server && adb start-server
   adb devices -l          # expect: <serial>  device  ... model:<name>
   ```
   If it shows `unauthorized`, re-accept the prompt; if the device is missing, check the cable and `lsusb`.
5. If the device never appears on Ubuntu: some vendors need udev rules (`51-android.rules`) per <https://developer.android.com/studio/run/device> — add only if `lsusb` lists the phone but `adb` cannot access it. Ubuntu packages `android-sdk-platform-tools-common` provide common rules [REF].
6. Record the device in `docs/project/PROJECT_STATUS.md`: manufacturer, model, Android version/API, SoC (`adb shell getprop ro.board.platform`), RAM, thermal behavior. This closes OQ-01.

## 7. Verification commands

```bash
flutter --version && dart --version
java -version                            # system JDK (may be 25: fine for non-Android use)
flutter config | grep jdk                # should show JDK 17
flutter doctor -v                        # Android toolchain ✓, connected device ✓; ignore Linux desktop/Chrome
adb devices -l
adb shell getprop ro.build.version.sdk   # phone API level (must be ≥ 29 per ADR-011)
```

Success: `flutter doctor -v` shows "Android toolchain" with no errors, and `flutter devices` lists the phone. M0 is done only when this is true.

## 8. Resource tuning (14 GiB RAM)

Create `~/.gradle/gradle.properties` (only after Gradle is first used; do not overwrite an existing file):

```
org.gradle.jvmargs=-Xmx3g -XX:+UseParallelGC
org.gradle.daemon=true
org.gradle.parallel=true
```

Close the IDE emulator if not used; test on the phone only.

## 9. Not required (and not to be installed "just in case")

Docker, Kubernetes, backend runtimes, Node.js, Python ML stacks, Chrome (for Flutter web), Linux desktop dependencies, the Android emulator, Xcode (Linux can't run it; iOS is v3.0 and needs macOS).
