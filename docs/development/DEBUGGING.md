# Debugging Guide

Commands assume the phone is connected (`adb devices -l` shows `device`) and the package id is `$PKG` (decided in OQ-02; default `com.camanime.app`). Commands marked [REF] vary by Android version; confirm on the device.

## 1. Diagnostic commands

```bash
adb logcat -c && adb logcat -v time | grep -E "CamAnime|flutter|AndroidRuntime|CameraX|Camera2|EGL|OMX|MediaCodec"
adb logcat --pid=$(adb shell pidof -s $PKG)                 # only our process
adb shell dumpsys media.camera | head -80                   # camera clients / who holds the camera
adb shell dumpsys meminfo $PKG                              # PSS, graphics, native heap
adb shell dumpsys gfxinfo $PKG framestats                   # frame timing (UI)
adb shell dumpsys SurfaceFlinger --latency                  # layer latency [REF]
adb shell dumpsys thermalservice                            # thermal status [REF]
adb shell dumpsys battery                                   # battery/charging
adb shell getprop | grep -E "ro.product|ro.build.version|ro.hardware|ro.board.platform"
flutter doctor -v
flutter logs
```

## 2. Flutter errors

| Symptom | Likely cause | Action |
|---|---|---|
| `flutter doctor`: Android toolchain issues | Missing cmdline-tools, licenses, SDK path | `flutter doctor --android-licenses`; set `ANDROID_HOME`; install cmdline-tools in SDK Manager |
| `MissingPluginException` | Plugin not registered / hot-restart vs hot-reload after native change | Full rebuild (`flutter run` again); verify registration in `MainActivity` |
| `PlatformException(CODE...)` | Native error | Look up code in API.md; check logcat |
| Black `Texture` but native logs frames | Wrong texture id/size, surface not producing, texture re-created without Dart rebuild | Log textureId on both sides; check `firstFrame` event; ensure Dart rebuilds on new id |
| UI jank in debug | Debug mode | Measure in `--profile` only |
| Hot reload doesn't affect Kotlin | Expected | Rebuild/restart |

## 3. Gradle / Android SDK errors

| Symptom | Likely cause | Action |
|---|---|---|
| "Unsupported class file major version" / Gradle can't run | JDK too new (this machine has JDK 25) | `flutter config --jdk-dir <jdk17>`; run `./gradlew -version` inside `android/` to see the JVM used |
| "SDK location not found" | `local.properties` missing | Flutter generates it; ensure `flutter.sdk`/`sdk.dir` valid; never commit it |
| "Failed to find Build Tools / platform" | Not installed | SDK Manager install the version named in the error |
| OOM / daemon killed | 14 GiB RAM pressure | Lower `-Xmx` (DEVELOPMENT_SETUP §8); stop emulator |
| Dependency resolution fails | Offline or repo issue | Check network for build time (runtime has none); `./gradlew --refresh-dependencies` |
| minSdk conflict | Library needs a higher minSdk | Don't lower; raise via ADR |
| Duplicate class / manifest merge | Transitive dependency | `./gradlew :app:dependencies`; inspect merged manifest in `build/` |

## 4. CameraX issues

| Symptom | Cause | Action |
|---|---|---|
| No frames, no error | `ImageProxy` not closed, or use case not bound, or lifecycle not STARTED | Check `close()` in `finally`; log lifecycle state |
| `CAMERA_IN_USE` / "Camera in use" | Another app, or our previous session not released | `dumpsys media.camera`; ensure unbind on pause |
| Rotated/mirrored preview | Ignoring `TransformationInfo`/sensor rotation | Verify rotation degrees logged; test front and rear |
| Stretched preview | Aspect ratio mismatch between texture and Dart widget | Use `previewSize` from native; fit by aspect |
| Binding fails with requested combination | Device doesn't support the use-case combo/resolution | Fallback config; log supported sizes |
| Slow lens switch | Camera reopen | Expected 200-500 ms [EST]; keep last frame |

## 5. Permission problems

`adb shell pm list permissions -d -g | grep -i camera`; `adb shell dumpsys package $PKG | grep -A15 "requested permissions"`; grant for tests `adb shell pm grant $PKG android.permission.CAMERA`; revoke `adb shell pm revoke ...`; reset: `adb shell pm reset-permissions` [REF]. "Blocked" detection depends on `perm.camera.requested` + `shouldShowRequestPermissionRationale` (FEATURE_SPECIFICATIONS F-01).

## 6. Native bridge issues

- Check channel names equal on both sides; check `apiVersion` handshake.
- A `Result` replied twice or never → crash/hang; log every call with an id in debug.
- Replies from non-main threads can crash: post to main.
- EventChannel with no listener drops events; Dart must listen before `camera.start`.

## 7. GPU and rendering errors

| Symptom | Cause | Action |
|---|---|---|
| Green/black/garbled frame | OES texture not updated, wrong sampler type, missing `updateTexImage()` | Verify GL thread owns the SurfaceTexture, call order |
| `GL_INVALID_OPERATION` etc. | Wrong thread/context, bad FBO | Add debug `glGetError` checks (debug builds only) |
| Flicker in the toon image | Hard `step()` thresholds, unstable mask | RENDERING_ENGINE §3.5; tune α |
| Shader compile errors on one vendor | Precision/qualifier differences | Log compile info; keep GLSL ES 3.00 features basic |
| Context lost after resume | Surface destroyed | Rebuild EGL surface; lifecycle checklist |
| Silhouette lagging the person | Mask latency | Measure `maskAgeMs`; lower input size; faster model; staleness fade |

Tools: `adb shell dumpsys SurfaceFlinger`, Android Studio GPU/CPU Profiler, Perfetto (`adb shell perfetto ...` [REF]), `systrace`-style sections via `android.os.Trace` markers in the render loop.

## 8. Recording and audio/video sync

| Symptom | Cause | Action |
|---|---|---|
| Video without audio | Mic permission denied, `AudioRecord` failed to init, muxer track not added | Check `has_audio` result and logs |
| Audio drift | Different clocks for audio vs video PTS | Rebase to common monotonic clock; compare first/last PTS |
| Offset constant (~100-300 ms) | Encoder/hardware latency | Apply measured compensation per device [OPEN] |
| Corrupt/unplayable MP4 | Muxer not stopped, process killed | Finalize in `finally`; stop before release; `ffprobe` file |
| Rotated video | Orientation metadata vs upright pixels | Output upright pixels, no rotation metadata |
| `MediaCodec` configure error | Unsupported size/profile | Probe `MediaCodecList`; fall back to 480p |
| Frame timestamps non-monotonic | SurfaceTexture timestamps reordered | Drop/clamp; log |

Inspect output: `adb pull /sdcard/Movies/Cam-Anime/<file>.mp4 && ffprobe -hide_banner <file>.mp4`.

## 9. When stuck

Reduce to the smallest reproduction (M1 preview only), record `adb logcat` + exact steps + device/OS, and add the finding here.
