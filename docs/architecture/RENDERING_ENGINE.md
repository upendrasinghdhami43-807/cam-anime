# Rendering Engine

Scope: Mode A in the MVP. All algorithms here are classical GPU image processing; no ML runs in the render path. Values marked [EST] are starting points to be tuned visually on the device in M4. Platform: OpenGL ES 3.0 / GLSL ES 3.00 (ADR-003).

## 1. Goals and constraints

- Cartoon look on the person only; the background is the unmodified camera image.
- ≤ ~8 ms GPU time per frame at 720p on the reference device [EST target; measured in M4/M8] to leave headroom for 30 FPS and the encoder.
- One render, three outputs (preview, encoder, photo).
- Styles are data (JSON parameters) over a fixed set of passes, so adding a style rarely requires GLSL.

## 2. Render graph

```
Camera OES texture ──P0 Prepare──▶ RGB_full (RGBA8, render res, upright, mirrored if front)
RGB_full ──P1 Smooth (separable, reduced taps)──▶ RGB_smooth
RGB_smooth ──P2 Stylize (quantize + color grade + edges + optional halftone)──▶ RGB_toon
(RGB_full, RGB_toon, Mask) ──P3 Composite──▶ OUT (RGBA8)
OUT ──blit──▶ Flutter surface | encoder surface | photo FBO
```

| Pass | Purpose | Input | Output |
|---|---|---|---|
| P0 Prepare | Sample `samplerExternalOES`, apply SurfaceTexture transform + rotation/mirror, copy into a normal 2D texture (multi-tap filters on OES are slower and less portable) | camera | `RGB_full` |
| P1 Smooth | Flatten texture and noise while keeping edges: separable approximated bilateral (e.g. 2×9 taps, range weight on luma difference) at full or half resolution | `RGB_full` | `RGB_smooth` |
| P2 Stylize | Cel shading, color quantization, edge ink, optional halftone/hatching | `RGB_smooth` (+`RGB_full` for fine edges) | `RGB_toon` |
| P3 Composite | Blend foreground toon over camera using the mask | `RGB_full`, `RGB_toon`, mask | `OUT` |

Original style = P0 → blit (P1-P3 skipped).

## 3. Cartoon techniques

### 3.1 Color quantization / cel shading
Convert to luma `L` (Rec.601). Quantize with soft steps to avoid banding artifacts and temporal shimmer:

```
band = L * N;  f = fract(band);  base = floor(band);
Lq = (base + smoothstep(0.5 - s, 0.5 + s, f)) / N        // s = softness (0.05-0.2)
color_toon = color * (Lq / max(L, ε))                    // preserve hue/chroma, remap brightness
```
Then saturation boost, contrast curve, optional palette tint (per style). Hue-preserving quantization keeps the subject recognizable (identity preserved per Mode A).

### 3.2 Edge detection (ink lines)
Sobel (3×3) or Difference-of-Gaussians on smoothed luma. `edge = smoothstep(t0, t1, magnitude)`; line color/width from style; width controlled by sampling offset in texels (scaled by render resolution so lines look the same at 720p and 480p). Computed on `RGB_smooth` to suppress noise and skin pores.

### 3.3 Silhouette outline
From the mask gradient: `ring = smoothstep(a, b, |∇mask|)` → thin outline around the subject (cartoon cut-out feel). Optional per style.

### 3.4 Halftone / hatching (Ink Comic / Noir Sketch)
Screen-space dot grid or line pattern modulated by `1 − Lq`; pattern scale in pixels-per-cell. No texture asset required.

### 3.5 Temporal stability
Quantization thresholds are the main source of flicker. Mitigate with soft steps (3.1), mild temporal blend of `L` (optional, a previous-frame texture [EST α 0.3]), and avoiding hard `step()`.

## 4. Foreground/background compositing

```
m   = texture(uMask, uv).r                       // 0..1 smoothed mask, sampled bilinearly
a   = smoothstep(uLo, uHi, m) * uEffectFade       // contrast + feather, e.g. lo=0.35, hi=0.65 [EST]
out = mix(camera, toon, a)                       // background pixels where a==0 are bit-identical to camera
out = mix(out, outlineColor, ring * uOutline)    // optional
```

- `uEffectFade` ramps 1→0 when no subject / mask stale (no ghost silhouettes).
- Mask flips/rotation follow the same transform as the image (`uMirror`, rotation matrix) so mask and image never disagree.
- AC-06 depends on `a == 0` ⇒ output equals camera exactly. A golden test asserts this for pixels where mask = 0.
- Known limitation: the mask is low-res and lags the camera by 1-3 frames; edges can show halos on fast motion. Tuning knobs: feather width, dilation/erosion, staleness fade. Better matting/guided filtering: v1.1.

## 5. Style definition format

`assets/styles/<id>.json` (loaded by the engine, mirrored into Dart catalog for names/thumbnails):

```json
{
  "id": "cel_pop",
  "version": 1,
  "smooth": { "radiusPx": 3.0, "rangeSigma": 0.12 },
  "quantize": { "bands": 5, "softness": 0.08, "saturation": 1.3, "contrast": 1.1, "tint": [1.0, 1.0, 1.0] },
  "edges": { "mode": "sobel", "t0": 0.10, "t1": 0.25, "widthPx": 1.5, "color": [0.05, 0.05, 0.08], "strength": 0.9 },
  "halftone": null,
  "silhouette": { "widthPx": 2.0, "color": [0.05, 0.05, 0.08], "strength": 0.8 }
}
```

MVP style set (parameters are starting guesses [EST]):

| ID | Look | Key parameters |
|---|---|---|
| `original` | Effect off | – |
| `cel_pop` | Bright flat colors, clean black ink | 5 bands, saturation 1.3, thin edges |
| `ink_comic` | High contrast, halftone shadows, thick ink | 4 bands, halftone on, thick edges |
| `soft_pastel` | Lifted, soft pastel, faint lines | 6 soft bands, saturation 0.9, brightness lift, thin faint edge |
| `noir_sketch` | Monochrome hatching on paper tone | grayscale, 4 bands, hatching, strong edges |

## 6. GPU implementation notes

- GL objects: 3 FBOs (`RGB_full`, `RGB_smooth`, `RGB_toon`, ping-pong for separable blur) allocated once per render size; resized on tier change.
- One full-screen triangle for all passes. Shader programs compiled at engine start; compile errors surface as `GL_INIT_FAILED` with the log in debug builds.
- Precision: `mediump` default, `highp` for coordinates/transform.
- Shaders loaded from `assets/shaders/*.vert|*.frag` with a documented uniform list in each header comment.
- EGL: shared context config with `EGL_RECORDABLE_ANDROID` for the encoder window surface; the Flutter window surface is created from the producer `Surface`.
- Render resolution follows the quality tier; the Flutter texture buffer size follows it too.
- GPU timing: `EXT_disjoint_timer_query` where available for the debug overlay [OPEN: availability per device].

## 7. Testing rendering

- Offscreen EGL instrumented tests (`androidTest`) run each style over fixed input images and mask patterns and compare against golden PNGs with a tolerance (per-channel ≤ 3/255 for deterministic passes; looser SSIM threshold across GPU vendors) [EST]. Goldens are generated on the reference device and re-baselined deliberately.
- Invariant tests: mask = 0 ⇒ output = input; mask = 1 ⇒ output = toon; Original ⇒ output = input.
- Visual review checklist in [TESTING](../development/TESTING.md).

## 8. Character rendering (v2.0, design intent only)

Mode B draws a 2D skeletal character (textured quads on bones, driven by smoothed pose landmarks) into the same compositing stage, after P3 or replacing the toon layer; the person is hidden by painting the character over the silhouette and/or inpainting the mask area from a cached background. Rig format, asset packs and background-reveal strategy are **not designed yet** (OQ-09) and nothing is scaffolded in the MVP.
