# Storage and Privacy

## 1. Principles

On-device only. No account. No network. The app touches the camera and microphone only while the user is actively using the camera screen, and never uploads anything.

## 2. Data inventory

| Data | Created by | Stored where | Leaves device? | User control |
|---|---|---|---|---|
| Camera frames | Camera | RAM/GPU only (never written unless captured) | No | – |
| Microphone audio | Recording | Encoded into the video file only; never kept separately | No | Choose "record without sound" |
| Photos / videos | Capture | MediaStore (`Pictures|Movies/Cam-Anime`) | Only if the user shares via system share sheet | Delete one/all in-app |
| Metadata (style, size, duration, timestamps) | App | SQLite in app-private storage | No | Deleted with item / "Delete all" / uninstall |
| Settings | User | SQLite | No | Reset settings |
| ML models | Bundled | APK assets | No | – |
| Logs | App | Logcat only (debug) | No | – |

Not collected: identity, location, contacts, device identifiers, advertising IDs, analytics, crash reports. Photos are **not** location-tagged: the app does not request location permission and writes no GPS EXIF [REC].

## 3. Permissions

| Permission | Why | When requested | Declared |
|---|---|---|---|
| `CAMERA` | Preview/capture | On first entry to the camera screen, after the rationale screen | Yes |
| `RECORD_AUDIO` | Video sound | On first record press, after an explanation dialog | Yes |
| `INTERNET` | – | Never | **Not declared** in release (enforced by `scripts/verify_no_internet.sh`, created in M8) |
| Storage (`READ/WRITE_EXTERNAL_STORAGE`, `READ_MEDIA_*`) | – | Not needed on API 29+ for the app's own MediaStore items | Not declared |

Notes: the debug/profile manifests Flutter generates include `INTERNET` for hot reload/DevTools; the release manifest must not. Verification uses `aapt2 dump permissions` on the release APK.

The camera is released when the app is not in the foreground; there is no foreground service and no background capture (AC-18). Android's camera/microphone privacy indicators remain the OS-level proof.

## 4. Local media storage

- Names: `CamAnime_YYYYMMDD_HHMMSS(.jpg|.mp4)`; collisions get a numeric suffix.
- Written with `IS_PENDING=1` and flipped to 0 after finalization so other apps never see partial files.
- Free-space guard before capture/record; recording monitors free space and stops gracefully near exhaustion.
- Because MediaStore files are visible to other apps with media access, the About/Privacy screen says so. A private "vault" is not in the MVP.

## 5. Deletion

- Per item: in-app delete removes file + row.
- All: "Delete all Cam-Anime media" in About & Privacy.
- Uninstall: app-private data (DB) is removed by Android; MediaStore items created by the app may be retained or removed per OS version behavior [REF, confirm in testing] — disclosed in the UI text ("Files saved to your gallery stay unless you delete them").

## 6. Backup behavior

- `android:allowBackup="false"` and `android:fullBackupContent`/`dataExtractionRules` excluding the database [REC]; settings and metadata are not useful without the files, and privacy is the product promise. Media in MediaStore is backed up by the user's gallery/backup provider outside this app's control.
- Future optional cloud backup would be an explicit opt-in feature (see [API](../integrations/API.md) §6), never default.

## 7. No-network operation

- Release manifest has no `INTERNET`; no dependency may require it. Library merge results are checked (a transitive dependency can add the permission silently): the verification script inspects the **merged** manifest/APK.
- Cleartext/network security config is not needed.
- Models, shaders, styles and fonts are all bundled; no first-run download.
- Open-source license list is generated at build time, not fetched.

## 8. Privacy text (user-facing draft)

> Cam-Anime works entirely on your phone. Your camera image and microphone sound are processed on the device and are never sent anywhere. Photos and videos you capture are saved to your gallery (Pictures/Cam-Anime and Movies/Cam-Anime). Cam-Anime uses the camera only while the camera screen is open, and the microphone only while you record a video with sound. You can delete everything the app saved at any time from About & Privacy.
