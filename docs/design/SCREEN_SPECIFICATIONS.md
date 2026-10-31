# Screen Specifications

IDs match [USER_FLOWS](../product/USER_FLOWS.md). Tokens and components: [DESIGN](DESIGN.md). Every screen implies TalkBack labels and large-font support.

## S-01 Splash
- **Purpose:** brand moment while the app initializes (DB open, settings read).
- **Hierarchy:** `Scaffold(bg.base) > Center(Logo + wordmark)`.
- **Actions:** none. **Navigation:** → S-02 if `onboarding.completed` is false, else → S-04. Max display 1 s (native splash via Android 12 SplashScreen API [REF] to avoid a double splash).
- **States:** loading (logo only); error (DB open failure) → full-screen error panel with Retry and "Reset local data" (confirm) [REC].

## S-02 Onboarding
- **Hierarchy:** `PageView(3) > [Illustration, Title(display), Body]` + dots + `Skip` (text) + `Next/Get started` (primary).
- **Pages:** (1) "Become a cartoon, live." (2) "Stays on your phone. No account, no internet." (3) "Camera and mic only when you capture."
- **Actions:** Next, Skip, Get started → set `onboarding.completed` → S-04 (replace route).
- **States:** static; no errors.

## S-03 Camera permission rationale
- **Hierarchy:** `Scaffold > Column(Icon, Title, Body, PrimaryButton, SecondaryButton?)`.
- **Variants:** `needsPermission` (Continue → system dialog), `denied` (Try again), `blocked` (Open app settings), `checking`.
- **Actions:** Continue/Try again/Open settings; back exits to previous (exits the app if first).
- **Navigation:** granted → S-04 camera (same route swaps content).
- **States:** loading (checking), error (bridge failure → generic error panel).

## S-04 Main camera (includes S-07 live preview, S-08 capture feedback, S-09 recording UI)
- **Hierarchy:**
  ```
  Stack
   ├─ CameraPreview (Texture, aspect fit)            // S-07
   ├─ TopBar (safe area): IconAction[Settings] · RecordingBadge(center) · IconAction[Flash]   (+ StatusChip)
   ├─ ZoomControl (above bottom bar, centered)
   ├─ SubjectHint (caption chip, conditional)
   └─ BottomBar: StyleChipRail(horizontal, 5 chips) / ModeToggle(Photo|Video) / Row[GalleryThumb · ShutterButton · IconAction[Flip]]
  ```
  The mode chip (S-05) is a small pill at the left of the style rail ("Mode A").
- **Actions:** shutter (photo capture / start-stop recording), flip, flash/torch, zoom (pinch/slider), style chip tap, "Mode A" pill → S-05, gallery thumb → S-10, settings → S-12, volume key = shutter (M7).
- **States:**
  - *Starting:* spinner placeholder (see DESIGN).
  - *Running:* live.
  - *Switching lens:* last frame + crossfade.
  - *Recording:* RecordingBadge visible; style rail disabled; mode toggle disabled; shutter shows stop; flip disabled (MVP: no mid-recording lens switch) [REC].
  - *Saving:* shutter disabled + progress ring.
  - *Error:* error panel overlays the preview (Retry; for `CAMERA_IN_USE` text "Another app is using the camera").
  - *Degraded:* StatusChip "Saving heat" / "Effects unavailable (basic preview)".
  - *No subject:* SubjectHint.
- **Navigation:** pushes S-10, S-12; sheets S-05/S-06 modal.
- **Lifecycle:** pause → release; resume → re-check permission and restart.

## S-05 Transformation mode selector (modal bottom sheet)
- **Hierarchy:** `Sheet > Title + ModeCard(Mode A, selected) + ModeCard(Mode B "Coming soon", disabled) + ModeCard(Animals "Coming soon", disabled)`.
- **Actions:** select Mode A (no-op), dismiss. **States:** static.
- **Note:** Disabled cards have text, not just reduced color, and `Semantics(enabled:false)`.

## S-06 Cartoon style selector (modal bottom sheet) and inline style rail
- **Hierarchy:** rail on S-04 shows all styles (5 chips) for one-tap switching; the sheet (opened by long-press/"more") is reserved for the future larger catalog and is **not built in the MVP** [REC]. Style list = `original, cel_pop, ink_comic, soft_pastel, noir_sketch`.
- **Actions:** tap chip → `render.setStyle`; persists `style.last_used`.
- **States:** loading (thumbnail skeleton), disabled during recording.

## S-07 Live preview — see S-04.

## S-08 Photo capture result
- **Behavior:** no full screen in MVP; inline feedback: flash overlay, thumbnail fly-in to GalleryThumb, snackbar "Saved" with [View] action (→ S-11 for that item).
- **Errors:** snackbar "Couldn't save photo" [Retry].

## S-09 Video recording interface — see S-04 (Recording state).
- **Extra:** On stop, "Saving…" overlay until `MediaResult`; snackbar "Video saved" [View].

## S-10 Local gallery
- **Hierarchy:** `Scaffold > AppBar(title "Gallery", back) > GridView(3 cols, GalleryTile)`; tile = thumbnail + video duration badge.
- **Actions:** tap tile → S-11 (index); back → S-04.
- **States:** loading (skeleton), empty (illustration + Open camera), error (read failure → Retry), partial (reconciling → silent).
- **Data:** `MediaRepository.watchAll()` (Drift stream, `created_at DESC`).

## S-11 Media preview/viewer
- **Hierarchy:** `PageView > [InteractiveViewer(photo) | VideoPlayer(video, controls)]` + overlay AppBar (back, share, delete, info).
- **Actions:** swipe between items, pinch zoom (photo), play/pause/seek (video), Share (system sheet), Delete (confirm dialog), Info (bottom sheet: date, size, resolution, style, duration).
- **States:** loading, video buffering (spinner), error (file missing → "This file was removed" + auto-remove row → back).
- **Navigation:** after delete → next item or back to S-10 if none.

## S-12 Settings
- **Hierarchy:** `ListView > Section("Camera") [Default camera segmented, Quality cap, Grid switch, Mirror front photos switch] > Section("Experience") [Haptics] > Section("Performance") [Performance mode] > Section("About") [About & Privacy → S-13] > Footer(version)` + "Developer" section (debug overlay) revealed after 7 taps on version [REC].
- **Actions:** change values (persist instantly), Reset settings (confirm).
- **States:** loading (read DB), error (fallback to defaults + snackbar).

## S-13 About and Privacy
- **Hierarchy:** `ListView > Header(app name, version) > PrivacyText(see STORAGE_AND_PRIVACY §8) > PermissionsList > OpenSourceLicenses > DangerZone[Delete all my Cam-Anime media]`.
- **Actions:** open licenses page (Flutter `showLicensePage` plus native notices), Delete all (confirm dialog listing count and size; result snackbar).
- **States:** deleting (progress), error (partial failure with count).
