# User Flows

Screen IDs (S-xx) are defined in [SCREEN_SPECIFICATIONS](../design/SCREEN_SPECIFICATIONS.md).

## 1. Navigation map

```
S-01 Splash
  ├─ first launch ─▶ S-02 Onboarding ─▶ S-04 Camera
  └─ returning ─────────────────────▶ S-04 Camera
S-04 Camera ──(no permission)──▶ S-03 Permission rationale ──▶ system dialog ──▶ S-04
S-04 Camera ─┬─ style rail (S-06, inline, one tap, no navigation)
             ├─ "Mode A" pill ─▶ S-05 Mode sheet (modal bottom sheet)
             ├─ thumbnail ──▶ S-10 Gallery ─▶ S-11 Media viewer
             ├─ capture ────▶ (inline) S-08 Capture confirmation toast/thumbnail
             └─ settings ───▶ S-12 Settings ─▶ S-13 About & Privacy
```

Back behavior: S-04 is the root. System back from S-10/S-12 returns to S-04. Back on S-04 exits the app. During recording, back stops recording only after a confirmation-free "stop and save" (recording is never discarded silently).

## 2. First launch

1. Splash (≤ 1 s, no network).
2. Onboarding, 3 pages: what it does, "everything stays on your phone", "camera and mic are used only when you capture". Skip allowed.
3. Camera screen. No permission yet → S-03 rationale → system dialog.
4. Granted → preview. Style defaults to the first style; mode is Mode A.

## 3. Permission workflow

```
Enter S-04
  has CAMERA? ── yes ─▶ start camera
      │no
      ▼
  S-03 rationale ─[Continue]─▶ system dialog
        ├─ granted ─────────────▶ start camera
        ├─ denied (can ask again) ─▶ S-03 "denied" state: [Try again]
        └─ denied permanently (don't ask again)
              ─▶ S-03 "blocked" state: [Open app settings]
                   └─ app resumes ─▶ re-check ─▶ granted? start camera : stay
```

Microphone is asked only when the user presses record (video mode) for the first time:

```
Press record, no RECORD_AUDIO
  ─▶ explanatory dialog [Allow microphone] / [Record without sound] / [Cancel]
       Allow ─▶ system dialog ─ granted ─▶ record with audio
                              └ denied ─▶ dialog again offering [Record without sound]
       Record without sound ─▶ record silent (indicator "Muted" shown on timer)
```

## 4. Camera workflows

- **Start:** S-04 resumed + permission → engine `start(lens, quality)` → preview texture appears; a placeholder (dark frame with spinner) shows until the first frame event.
- **Switch camera:** tap switch → engine rebinding; preview freezes on last frame with a short crossfade; style/mode preserved; flash state resets to Off; zoom resets to 1×.
- **Flash/torch:** photo mode: Off/On/Auto (rear only if supported); video mode: torch Off/On. Front camera: control hidden unless supported.
- **Zoom:** pinch or slider; clamps to the camera's min/max; value shown as "1.0×".
- **Style change:** tap a chip in the inline style rail (S-06) → applies live (shader uniform change, no camera restart).
- **App background:** `onPause` → engine releases the camera (and finalizes any recording). `onResume` → re-check permission, restart.
- **No subject detected:** the unstyled frame is shown, plus a subtle hint "Step into the frame" after 2 s of no person (mask coverage below threshold).

## 5. Capture workflows

**Photo:** tap shutter → haptic + shutter animation → engine renders/saves JPEG into MediaStore → DB row inserted → thumbnail updates in the gallery shortcut → toast "Saved". Failure → snackbar with reason and Retry.

**Video:**
1. Switch to Video via the mode toggle.
2. Tap record → (mic flow if needed) → recording indicator + timer start; style changes are locked during recording in MVP [REC] (avoids mid-clip shader hiccups), zoom and torch stay available.
3. Tap stop → "Saving…" → file finalized → DB row → thumbnail → toast.
4. Interruptions: incoming call/app backgrounded → stop, finalize, keep the clip, show message on return. Storage full / encoder error → finalize if possible, message.

## 6. Gallery workflows

- Grid (3 columns) ordered newest first. Tap → viewer (swipe between items). Viewer: share (system share sheet), delete (confirm dialog), info. Video plays inline with standard controls.
- Delete: confirm → remove MediaStore item and DB row → grid updates → undo is not offered (the file is gone) [REC].
- Empty state: illustration + "Your creations will appear here" + [Open camera].
- Missing files (deleted externally): row is hidden and purged during reconciliation on gallery open.

## 7. Error and recovery workflows

| Error | Detection | User sees | Recovery |
|---|---|---|---|
| Permission denied | permission result | S-03 denied state | Try again |
| Permission blocked | rationale false + denied | S-03 blocked state | Open settings, auto re-check on resume |
| Camera in use by another app | CameraX error / `CAMERA_IN_USE` | Full-preview error panel | Retry button; auto-retry on resume |
| Camera disconnected / fatal camera error | CameraX error callback | Error panel | Retry, which re-creates the session |
| No camera hardware (e.g. no front) | lens query | Switch button hidden | — |
| GL/GPU init failure | engine error `GL_INIT_FAILED` | Error panel with "Use basic preview" fallback [REC: plain preview without effects] | Retry; logs diagnostic |
| Model failed to load/verify | checksum/load error | Banner "Effects unavailable"; plain preview | Retry; report via debug screen |
| Low storage | StatFs check before record/photo | Dialog | Open storage settings |
| Encoder failure | MediaCodec exception | Message; partial file finalized if valid | Retry |
| Thermal escalation | `PowerManager` thermal status | Chip "Performance mode: saving heat" | Automatic; user may force in settings |
| Sustained slow frames | frame-time monitor | Quality drops one tier + chip | Automatic |

## 8. Settings and privacy flows

- Settings → About & Privacy → plain-language summary: what is accessed, what is stored, where, that nothing is uploaded; [Delete all my Cam-Anime media] (confirm, typed word not required) removes files created by the app and DB rows.
- Reset settings → confirm → defaults.
