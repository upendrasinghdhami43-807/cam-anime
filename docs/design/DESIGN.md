# Design System

Direction: **camera-first, dark, playful but restrained.** The preview is the interface; controls float over it. No dashboard, no cards on the main screen.

## 1. Design principles

1. **Preview first.** ≥ 70 % of the camera screen is the live image. Controls are overlays with translucent scrims.
2. **One-hand reach.** Primary actions (shutter, style, flip) sit in the bottom 40 % of the screen.
3. **Show the effect, not settings.** Style choice is visual (thumbnail chips), not text menus.
4. **Calm chrome.** Neutral dark UI so the cartoon colors are the only saturated thing on screen.
5. **State is visible.** Recording, muted, performance saving and errors are always visible, never silent.
6. **Honest and private.** Plain-language permission and privacy messages.

## 2. Color system (HEX)

Dark theme is primary (camera). A light theme applies to Settings/About/Gallery-empty only if the system theme is light; the camera screen is always dark [REC].

| Token | HEX | Use |
|---|---|---|
| `bg.base` | `#0B0B10` | App background, camera letterbox |
| `bg.surface` | `#16161F` | Sheets, dialogs |
| `bg.surfaceRaised` | `#20202C` | Chips, list tiles |
| `scrim.top` / `scrim.bottom` | `#0B0B10` @ 60 % → 0 % | Gradients behind overlay controls |
| `text.primary` | `#F4F4F8` | Main text (contrast on `bg.base` ≈ 17:1) |
| `text.secondary` | `#B4B4C4` | Secondary text (≈ 9:1) |
| `text.disabled` | `#6C6C80` | Disabled |
| `brand.primary` | `#FF5C8A` | Accent, selected style ring, primary buttons |
| `brand.secondary` | `#7B5CFF` | Secondary accent, focus rings |
| `brand.tertiary` | `#26D6C2` | Success, "Saved" |
| `state.recording` | `#FF3B30` | Record dot, timer |
| `state.warning` | `#FFB020` | Thermal/performance saving |
| `state.error` | `#FF6B6B` | Errors (on dark) |
| `on.brand` | `#0B0B10` | Text/icon on brand.primary (≈ 7:1) |
| `outline` | `#34344A` | Dividers, chip borders |

Contrast ratios are computed targets [EST]; verify with a tool during M7 (NFR-09).

## 3. Typography

Font: **Nunito** (rounded, friendly, SIL OFL [REF, confirm in M1]) bundled as assets (offline). Fallback: system sans.

| Style | Size / line | Weight | Use |
|---|---|---|---|
| `display` | 28 / 34 | 800 | Onboarding titles |
| `title` | 20 / 26 | 700 | Screen/sheet titles |
| `body` | 16 / 24 | 400 | Body |
| `label` | 14 / 20 | 600 | Buttons, chips |
| `caption` | 12 / 16 | 600 | Zoom value, timer sub-label |
| `timer` | 20 / 24 | 700, tabular figures | Recording timer |

Support system font scaling up to 200 %; overlay labels have min height and wrap/elide; camera controls use icons so they don't depend on text size.

## 4. Spacing, shape, elevation

- Spacing scale (dp): 2, 4, 8, 12, 16, 24, 32, 48. Screen padding 16.
- Radius: chips 20, buttons 28 (pill), sheets 24 top, thumbnails 12.
- Min touch target 48×48 dp (shutter 76 dp, icon buttons 48 dp).
- Elevation: none on camera overlays (use scrims); sheets use tonal surface color (Material 3).
- Icon set: Material Symbols (rounded), size 24.

## 5. Components

| Component | Spec | States |
|---|---|---|
| **ShutterButton** | 76 dp circle, white 4 dp ring, inner 60 dp: photo = white; video idle = `state.recording` ring; video recording = rounded-square 28 dp inner, red | idle, pressed (scale 0.92), recording (pulsing ring 1 s), disabled (40 % opacity, during saving), focus (visible ring) |
| **ModeToggle** (Photo/Video) | Two-segment pill above the shutter | selected, unselected, disabled while recording |
| **StyleChip** | 56 dp rounded thumbnail (static preview image per style) + 12 sp label; selected = 2 dp `brand.primary` ring | default, selected, pressed, disabled (recording), loading (thumbnail skeleton) |
| **IconAction** | 48 dp translucent circle with icon (flip, flash, settings, gallery) | default, active (filled icon + `brand.primary`), disabled, hidden when unsupported |
| **ZoomControl** | Vertical-less: pinch + a small pill "1.0×" that expands to a slider when tapped | idle, adjusting, at-limit |
| **GalleryThumb** | 40 dp rounded last-capture thumbnail; empty = outlined placeholder | loaded, empty, loading |
| **RecordingBadge** | Red dot + `timer`, top center; "Muted" mic-off icon if no audio | recording, muted |
| **StatusChip** | Top-left pill for "Saving heat" / "Effects unavailable" | warning, error |
| **PrimaryButton / SecondaryButton / TextButton** | Pill; primary uses `brand.primary` | enabled, pressed, disabled, loading (spinner replaces label, width constant) |
| **Sheet** | Modal bottom sheet, drag handle, 24 dp top radius | open, dragging |
| **Toast/Snackbar** | Bottom, above controls; `Saved` uses `brand.tertiary` check | info, success, error w/ action |

### Button state details
Default → pressed (scale 0.96, 80 ms) → disabled (opacity 0.4, no ripple) → loading. Keyboard/switch-access focus shows a 3 dp `brand.secondary` ring.

## 6. Loading, empty, error states

| State | Treatment |
|---|---|
| **Camera starting** | Dark frame, centered 36 dp spinner and "Starting camera…" after 400 ms (avoid flash); no layout shift |
| **Style loading** | Skeleton shimmer on chips (< 300 ms) |
| **Gallery empty** | Simple illustration, "Your creations will appear here", [Open camera] |
| **Gallery loading** | Grid skeleton tiles |
| **Permission / error panel** | Icon, title, one-sentence explanation, primary action (Retry / Open settings), secondary (Learn more); never a raw exception text |
| **No subject** | Unstyled preview + caption chip "Step into the frame" |

## 7. Responsive behavior

- Portrait phones are the MVP target (Activity locked to portrait [REC]). Controls anchor to safe areas (cutouts, gesture bar) via `SafeArea`.
- Preview keeps the camera aspect ratio (9:16 / 3:4 center-fit) with `BoxFit.cover` cropping only when explicitly designed; default is fit with black bars rather than silent cropping so framing matches the saved result [REC; decide after M2].
- Small phones (≤ 360 dp wide): style chips scroll horizontally; labels hidden under 340 dp.
- Tablets/foldables/landscape: not designed in MVP; app remains usable in the portrait lock.

## 8. Accessibility

- TalkBack: every control has a `Semantics` label and role (e.g., "Take photo", "Switch to front camera", "Style: Cel Pop, selected"). Recording state announced via live region ("Recording started", elapsed time every 10 s optional).
- Touch targets ≥ 48 dp; the shutter has volume-key alternative (hardware key triggers capture) [REC, M7].
- Contrast ≥ 4.5:1 for text, ≥ 3:1 for icons/outlines.
- No information by color alone (recording dot + timer + label; warning chip has text + icon).
- Respect "Remove animations": reduce pulsing, crossfade durations to 0.
- Haptics are optional and not the only feedback.
- Large font scale tested at 200 %.

## 9. Animation and interaction

| Interaction | Motion |
|---|---|
| Shutter press | Scale 0.92, 80 ms; flash overlay (white 15 % → 0, 120 ms) |
| Style selected | Ring grows 150 ms, shader change instant on next frame, no camera flicker |
| Lens flip | 200 ms blur/crossfade of last frame while the camera rebinds |
| Sheet open/close | 250 ms standard easing (`Curves.easeOutCubic`) |
| Record start | Dot fades in, shutter morphs 150 ms |
| Capture thumbnail | Scales into the gallery thumb, 250 ms |
| Reduced motion | Replace with instant/opacity changes |

Durations max 300 ms; no animation may delay a capture action.
