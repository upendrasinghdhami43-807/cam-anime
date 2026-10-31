# Product Requirements Document (PRD)

Status: draft v0.1 · Owner: project owner · Labels: see [README](../../README.md#evidence-labels-used-in-the-docs)

## 1. Product vision

Cam-Anime turns the phone camera into a live cartoon lens. A user opens the app, picks a style, and sees themselves (or a friend) drawn as a cartoon in real time while the room, street, or scenery around them stays real. They can snap a photo or record a video with sound and keep it on their phone, privately, with no account and no internet.

## 2. Problem statement

- Existing "cartoon" camera filters either stylize the whole frame (the background looks fake) or are cloud-based (slow, costs money, uploads personal photos).
- Users, especially creators and families, want a fun, private, instant effect that works anywhere, including offline and in low-connectivity regions.
- The team has zero budget for paid inference APIs, so the product must run on the device.

## 3. Target users and personas

| Persona | Description | Needs |
|---|---|---|
| **Maya, 19, short-video creator** | Posts clips to social apps daily | Live preview, video with sound, good-looking styles, quick save to gallery |
| **Rohan, 34, parent** | Wants fun photos/videos with kids | Simple UI, privacy, works offline, no account |
| **Sita, 27, casual user on mid-range phone** | Budget Android phone, limited data | Smooth preview, no battery drain, no download |
| **Dev, 22, hobbyist/early tester** | Curious, reports bugs | Settings, performance mode, clear errors |

## 4. User stories

- US-01 As a user, I open the camera and understand why the app needs camera access before the system dialog appears.
- US-02 As a user, I see a live camera preview and can switch between the front and rear cameras.
- US-03 As a user, I can turn on flash/torch and zoom.
- US-04 As a user, I pick a cartoon style and see my body become a cartoon live while the background stays real.
- US-05 As a user, I take a photo of the stylized result and find it in my gallery.
- US-06 As a user, I record a video with my voice/ambient sound and play it back stylized.
- US-07 As a user, I browse, view, share, and delete my creations inside the app.
- US-08 As a user, I use the entire app with airplane mode on.
- US-09 As a user, I recover gracefully when I deny a permission or the camera is busy.
- US-10 As a user on a hot or slow phone, the app lowers quality instead of freezing.
- US-11 As a privacy-conscious user, I can read what the app stores and delete it all.

## 5. Functional requirements (MVP)

| ID | Requirement | Priority |
|---|---|---|
| FR-01 | Explain and request camera permission in context; never before the camera screen is entered | Must |
| FR-02 | Live camera preview (rear default) | Must |
| FR-03 | Front/rear switch, preserving the selected style; mirrored front preview | Must |
| FR-04 | Flash (photo) / torch (video) control where the device supports it; hidden otherwise | Must |
| FR-05 | Zoom: pinch gesture and slider within the device zoom range | Must |
| FR-06 | Real-time human foreground segmentation for a single primary subject | Must |
| FR-07 | Mode A stylization applied to the segmented subject only; background unchanged | Must |
| FR-08 | At least 4 cartoon styles plus "Original" (effect off) | Must |
| FR-09 | Photo capture of the stylized output, saved to the device gallery (MediaStore) and indexed in-app | Must |
| FR-10 | Video recording of the stylized output, H.264 + AAC in MP4, saved to MediaStore | Must |
| FR-11 | Microphone permission requested at first video record; denial allows silent recording after explicit confirmation | Must |
| FR-12 | In-app gallery: grid, full-screen viewer (photo/video playback), share, delete | Must |
| FR-13 | Settings: default camera, quality cap (720p/480p/auto), grid overlay, haptics, mirror front photos, performance mode | Must |
| FR-14 | Fully offline: no network permission in release | Must |
| FR-15 | Error handling and permission recovery (denied, permanently denied, camera busy/disconnected, low storage, encoder failure, thermal) | Must |
| FR-16 | Onboarding (shown once) and About/Privacy screen | Should |
| FR-17 | Adaptive quality: lower resolution/FPS on thermal or sustained-slow conditions with visible indicator | Must |
| FR-18 | Mode selector UI listing Mode A (active) and later modes as "coming soon", non-interactive | Could |

## 6. Non-functional requirements

Targets below are engineering goals, **not measured**. Pass/fail criteria are in [PERFORMANCE](../performance/PERFORMANCE.md).

| ID | Requirement | Target |
|---|---|---|
| NFR-01 | Preview frame rate, one person, 720p, reference device, profile build | median ≥ 24 FPS, goal 30 [EST] |
| NFR-02 | Glass-to-glass latency (move → see it on screen) | ≤ 150 ms goal [EST] |
| NFR-03 | Cold start to interactive camera (permission already granted) | ≤ 2.5 s [EST] |
| NFR-04 | App memory (PSS) while previewing | ≤ 400 MB [EST] |
| NFR-05 | Release APK size including bundled models | ≤ 80 MB [EST] |
| NFR-06 | No network access | `INTERNET` absent from release manifest; verified by script |
| NFR-07 | Stability | No camera/GL/codec resource leak across 50 background/foreground cycles |
| NFR-08 | Thermal | Adaptive fallback engages before OS severe throttling; no forced shutdown during 10-min recording on reference device |
| NFR-09 | Accessibility | TalkBack labels on all controls, touch targets ≥ 48 dp, contrast ≥ 4.5:1 for text |
| NFR-10 | Battery | Measured and recorded in M9; no promise until measured |
| NFR-11 | Privacy | No frame, audio, or media leaves the device |
| NFR-12 | Supported Android | minSdk 29 (Android 10) [REC, OQ-04] |

## 7. MVP scope

In: everything in FR-01…FR-18, Mode A only, **one human subject**, Android only, English UI only (strings externalized for later localization).

## 8. Out of scope (MVP)

Mode B character replacement, animal transformation, multiple people, facial-expression tracking, character customization/asset packs, accounts, cloud backup, payments, analytics, iOS, tablets/foldable-specific layouts, video import/editing, audio effects, localization beyond English, widgets, social sharing integrations beyond the system share sheet.

## 9. Success metrics

Because the MVP collects no telemetry, metrics come from device testing and (later) voluntary feedback:

| Metric | Target |
|---|---|
| Reference device meets NFR-01 and NFR-08 | 100 % of the acceptance test run |
| First-run to first saved photo, tester observation | ≤ 60 s for 4 of 5 testers |
| Crash-free during a 30-min scripted soak on reference device | 100 % [EST] |
| Mid-tier device (Tier B) preview at ≥ 20 FPS with fallback | pass on at least one Tier B phone |
| Tester satisfaction "looks like a cartoon, background real" | ≥ 4/5 for at least 3 of 5 testers [EST] |

## 10. Acceptance criteria (MVP release)

Each criterion is traced to tests in [TESTING](../development/TESTING.md).

| ID | Criterion |
|---|---|
| AC-01 | On a fresh install, opening the camera shows a rationale screen, then the system permission dialog; granting shows the rear preview within 2 s. |
| AC-02 | Denying permission shows recovery UI; "permanently denied" offers a working link to app settings; returning from settings with permission granted shows the preview without restarting the app. |
| AC-03 | Front/rear switching works ≥ 20 times in a row without a black frame lasting > 1 s or leaked camera (verified via `adb shell dumpsys media.camera`). |
| AC-04 | Preview orientation is upright and correctly mirrored (front) in portrait and after rotating the device, on rear and front cameras. |
| AC-05 | Backgrounding and resuming the app 50 times leaves the camera functional with no leaked EGL/codec/camera sessions (logcat + dumpsys). |
| AC-06 | With one person in frame, the person is stylized and the background pixels outside the mask feather band are identical to the unstyled camera image (verified by the render golden test and visual check). |
| AC-07 | Each of the 4 styles + Original can be selected live without restarting the camera, with no frame drop > 500 ms. |
| AC-08 | Photo capture saves a JPEG that visually matches the preview framing and style, appears in the system gallery and in-app gallery within 2 s. |
| AC-09 | A 60 s video records with audio, plays in the system player with audible sound, correct orientation, A/V offset ≤ 80 ms, and duration within ±0.5 s of the timer. |
| AC-10 | A 10-minute recording completes (or is stopped gracefully with a message and a valid saved file) without app crash or ANR on the reference device. |
| AC-11 | Release APK manifest contains no `android.permission.INTERNET`; the full flow works in airplane mode. |
| AC-12 | Median preview FPS ≥ 24 at 720p with one person on the reference device in a profile build over a 5-minute measurement. |
| AC-13 | When thermal status reaches the configured threshold, the app reduces quality, shows an indicator, and does not crash. |
| AC-14 | Gallery lists all saved items, supports view/share/delete; deleting removes both file and DB row; externally deleted files are handled without a crash. |
| AC-15 | Low storage (< 200 MB free [EST]) blocks recording with a clear message; storage filling during recording ends it with a valid file. |
| AC-16 | TalkBack can operate every control on the camera, gallery, and settings screens. |
| AC-17 | No microphone permission is requested before the user starts a video recording. |
| AC-18 | The app never records or accesses the camera while in the background. |

## 11. Assumptions and dependencies

- Reference device: not yet identified (OQ-01). Acceptance numbers are provisional until it is.
- Pretrained segmentation model with a license permitting commercial redistribution can be found and bundled (OQ-06). Not verified.
- The classical cartoon shader on top of a segmentation mask is acceptable to the owner as "Mode A" for MVP; neural style transfer is deferred (OQ-07).

## 12. Mode A vs Mode B (technical differences)

| Aspect | Mode A: real-subject stylization | Mode B: character replacement |
|---|---|---|
| Output | The user's own pixels, cartoonized | A separate rendered character |
| Identity (face, clothes) | Preserved as far as shader allows | **Not preserved** unless the character is built to imitate it |
| Core tech | Segmentation mask + image filters/shader | Pose landmarks → skeleton → rig → 2D/3D rendering |
| Hardest problem | Mask quality at hair/edges; temporal flicker; cartoon look from classical filters | Revealing the background behind the removed person (needs inpainting or the character covering the silhouette); pose jitter; rig quality; art assets |
| Art/assets needed | Style parameters only | Character art, rigs, animations (heavy) |
| MVP? | Yes | No (v2.0) |
