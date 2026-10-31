# Security and Privacy Threat Model

Scope: Android MVP, offline, no backend. Principle: reduce attack surface by having none to speak of (no network, no accounts, no IPC exposure), then protect the user's media and permissions.

## 1. Assets

| Asset | Sensitivity |
|---|---|
| Live camera frames and microphone audio | High (privacy of user and bystanders) |
| Saved photos/videos | High |
| Metadata DB (when/what style) | Low-medium |
| ML models and shaders (app IP) | Low (APK-distributed) |
| Signing keys | Critical (release integrity) |

## 2. Trust boundaries

Flutter UI ↔ native engine (same process, trusted but validated); app ↔ OS services (camera, MediaStore); app ↔ other apps (share intents, MediaStore visibility); developer machine ↔ repository ↔ release artifacts.

## 3. Threats and mitigations

| # | Threat | Mitigation |
|---|---|---|
| T1 | Hidden/unauthorized camera or mic use | Camera only bound while the activity is foreground and on the camera screen; mic only during recording; no services, no background capture; AC-17/AC-18 tests; OS indicators remain |
| T2 | Data exfiltration | No `INTERNET` permission (release); no analytics/crash/ad SDKs; dependency review; merged-manifest check (AC-11) |
| T3 | Other apps reading saved media | MediaStore media is readable by apps with media permissions: disclosed in privacy text. No private vault in MVP (post-MVP option) |
| T4 | Exported components abused (intents) | `android:exported="false"` for everything except the launcher activity; no custom intent filters, content providers or services in the MVP; share uses system share sheet with URI grants |
| T5 | Malicious/corrupted model file | MVP loads only bundled assets verified by SHA-256 against a manifest embedded in the app; no loading from external storage; fail closed (`MODEL_INTEGRITY_FAILED` → plain preview). Post-MVP downloaded models need signature verification |
| T6 | Vulnerable dependency (Flutter plugins, CameraX, ML runtime, SQLite) | Minimal dependency set; lockfiles committed; review release notes/advisories at each milestone; `flutter pub outdated` + Gradle dependency report; license + maintenance check before adding (AGENTS §6) |
| T7 | Supply-chain tampering | Fetch SDKs from official sources; verify checksums where provided; pin versions by lockfile; no unreviewed scripts piped to shell |
| T8 | Local data theft on rooted/compromised device | DB stores no secrets or PII; media is user content under OS storage protections; not claiming protection against a compromised OS |
| T9 | Backups leaking data | `allowBackup=false`, extraction rules exclude DB |
| T10 | Debug build shipped | Release checklist: no debug overlay, `debuggable=false`, no verbose logs; check in release validation |
| T11 | Native memory-safety bugs | MVP is Kotlin/Dart (memory-safe); the ML runtime is the main native surface; ADR-004 means no custom C++; if C++ is added: sanitizers, bounds checks, fuzz input boundaries |
| T12 | Logs leaking data | No frame/audio/user path logging; logcat is local but readable via adb on debug devices |
| T13 | Keystore leak | Outside repo, `.gitignore` entries, backups in a password manager; Play App Signing |
| T14 | Bystander privacy | Product guidance in onboarding ("ask before recording others"); no cloud upload by design |
| T15 | Screen overlay/tapjacking on permission dialogs | Rely on OS permission dialogs; no custom permission UI that mimics them |

## 4. Permissions (summary)

`CAMERA`, `RECORD_AUDIO` only. See [STORAGE_AND_PRIVACY §3](../data/STORAGE_AND_PRIVACY.md). Any new permission requires an ADR and updates here.

## 5. Local data protection

DB in app-private storage (Android file-based encryption protects at rest on modern devices [REF]). SQLCipher is **not** used: the DB holds no secrets; adding it would add native code and size for no threat addressed. Revisit if sensitive data is ever stored.

## 6. Model security

Models are inputs to a native parser; treat them as code-equivalent. Bundled only; hash-verified; catalog license/provenance recorded; never accept a model path from the UI or intents.

## 7. Dependency and license review

Process: (1) check license compatibility with a commercial closed-source app (Apache-2.0/MIT/BSD fine; GPL/AGPL/LGPL and non-commercial or "research only" licenses are blocked unless approved), (2) maintenance (recent releases), (3) transitive permissions in the merged manifest, (4) size. Recorded in TECHNICAL_DECISIONS / MODEL_CATALOG. Generate the third-party notice file at release.

## 8. Privacy assumptions

- Users consent per OS permission dialogs and are informed by the rationale screens.
- Saved media may contain faces of the user and others; stays local.
- The app is not directed at children under 13 specifically; if it will be, the privacy and store policies need a legal review [OPEN].
- Legal/compliance (GDPR, Play policies) assessment has not been performed; the design collects no personal data, which minimizes scope, but a legal review before store release is recommended [OPEN].

## 9. Security checks by milestone

M1: exported flags, permissions list. M5-M6: MediaStore handling, URI grants. M8: `verify_no_internet.sh`. M9: dependency audit, release build inspection (`debuggable`, `allowBackup`, merged manifest, signing).
