# Coding Standards

Enforcement: analyzers and formatters first, review second. If a rule conflicts with the tooling default, the tooling wins and the rule is corrected here.

## 1. Dart / Flutter

- **Lints:** `flutter_lints` baseline plus project `analysis_options.yaml` (strict casts/inference/raw-types enabled: `analyzer: language: strict-casts: true, strict-inference: true, strict-raw-types: true` [REF syntax]). `flutter analyze` must be clean.
- **Format:** `dart format` (default 80 cols); no manual alignment.
- **Naming:** files `snake_case.dart`; types `UpperCamelCase`; members `lowerCamelCase`; constants `lowerCamelCase`; private with `_`. Providers `fooProvider`.
- **Structure:** feature-first (`features/<f>/{presentation,domain,data}`); presentation never imports `data` directly except via providers; no cross-feature imports of `presentation`.
- **Widgets:** small, `const` constructors, no business logic in `build`; long widgets split into widgets (not helper methods returning widgets).
- **State:** Riverpod notifiers; immutable state classes (plain Dart classes with `copyWith`; add `freezed` only by ADR).
- **Async:** no fire-and-forget without `unawaited` + error handling; cancel/dispose subscriptions (EventChannel streams) in `ref.onDispose`.
- **Errors:** native errors become a sealed `EngineError`; UI shows mapped messages (DESIGN error panel), never `toString()` of exceptions. No empty `catch`.
- **Logging:** `core/logging` wrapper over `dart:developer`'s `log`; no `print`; no user media paths or pixel data.
- **Docs:** `///` on public APIs of `core/` and each feature's domain layer.
- **Tests:** mirror `lib/` under `test/`; fakes over mocks where practical; golden tests only for stable widgets.

## 2. Kotlin (Android engine)

- Official Kotlin style (`kotlin.code.style=official`); format with the IDE/ktlint if added by ADR.
- Packages `com.camanime.engine.<bridge|camera|gl|vision|record|media|perf>`; internal visibility by default (`internal`), only `bridge` exposes public types.
- No `!!` in production code; prefer sealed results (`Result`-like sealed classes) over exceptions across component boundaries; exceptions only at the bridge, mapped to error codes.
- **Threading:** each component documents which thread it runs on and which thread may call it (KDoc `@thread`). GL calls only on the GL thread. Long work never on main. Use named single-thread executors (named threads) for camera, analysis, inference, gl, io.
- **Resources:** each resource (camera provider, `ImageProxy`, EGL objects, `MediaCodec`, `AudioRecord`, `Surface`, `SurfaceTexture`) has one owner and `close()`/`release()` in a `finally` or a lifecycle callback; `ImageProxy.close()` always.
- **Allocation:** no allocations in per-frame paths (reuse buffers); avoid boxing in hot loops.
- **Logging:** `android.util.Log` via a small `Logger` wrapper with a `CamAnime/` tag prefix; no frame/user data; verbose only in debug.
- **KDoc** on public API and non-obvious invariants only.
- **Tests:** JVM unit tests for pure logic (mask smoothing, quality controller state machine, permission-state mapping, error mapping); instrumented tests for GL/camera/codec.

## 3. GLSL

- `#version 300 es`; header comment lists inputs/uniforms/outputs and expected ranges; no magic numbers without a named uniform or constant; shaders are files, not strings.

## 4. C++ (not used in the MVP)

If introduced via ADR-004: C++17, CMake, `clang-format` (Google or LLVM style fixed in the ADR), RAII only, no exceptions across JNI, `-Wall -Wextra -Werror` for project code, sanitizers (ASan/UBSan) in a debug config, no global mutable state, every JNI function validates arguments.

## 5. Error handling and logging (cross-cutting)

- Every failure path ends in: a typed error, a user-visible recovery option, and a log line (without PII).
- Fail closed for privacy: if unsure whether the camera is needed, release it.

## 6. Documentation

- Update the affected doc in the same commit (API.md for bridge changes, DATABASE.md for schema, TECHNICAL_DECISIONS.md for decisions).
- Evidence labels ([ENV] [REF] [REC] [EST] [OPEN]) in docs; no unlabeled external claims.

## 7. Code review checklist

- [ ] Within the current milestone and task; no unrelated edits
- [ ] No frames/pixels in Dart or on channels
- [ ] Threading and resource ownership clear; releases on every path
- [ ] No per-frame allocations introduced
- [ ] Tests included/updated; analyzer clean
- [ ] Bridge/DB/docs updated together
- [ ] No new dependency without an ADR/approval; license checked
- [ ] No secrets, no network, no PII in logs
- [ ] Device-only behavior listed as "requires real-device validation"
