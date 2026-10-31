# Model Asset Management

MVP rule: **models are bundled in the APK, never downloaded.** This keeps the app offline-first and removes a whole class of supply-chain risk. The design below is future-proof for downloadable models without changing the engine.

## 1. Versioning

- Each model has an ID and integer version: `person_seg@1`. Changing weights, preprocessing or output semantics increments the version.
- `models/manifest.json` (engine assets) lists every model:

```json
{
  "schema": 1,
  "models": [
    {
      "id": "person_seg",
      "version": 1,
      "file": "models/person_seg_v1.tflite",
      "sha256": "<64 hex chars>",
      "sizeBytes": 0,
      "runtime": "mediapipe-tasks | litert",
      "input": { "width": 256, "height": 256, "format": "rgb_float32", "normalize": "0..1" },
      "output": { "kind": "mask", "range": "0..1" },
      "license": "<SPDX or name>",
      "licenseFile": "third_party/licenses/<file>",
      "source": "<URL>"
    }
  ]
}
```
(The manifest values are filled when a model is actually adopted; the example above contains placeholders by design.)

- The manifest embeds the app-expected hash; the model file hash is computed at build time by a script (`scripts/gen_model_manifest.sh`, created with the first model) and verified at runtime.

## 2. Local storage

- MVP: `assets/models/` inside the engine module → packaged in the APK (read via `AssetManager`). `aaptOptions`/`androidResources.noCompress` for `.tflite` so the file can be memory-mapped [REF; confirm current Gradle DSL].
- Large binary files in git: decide Git LFS vs checking models in directly (OQ-11). Until decided, no model binary is committed.

## 3. Loading

1. `ModelRepository.open(id)` reads the manifest, locates the asset, streams it through SHA-256, compares with the manifest.
2. On match: memory-map/copy into the runtime (the runtime's recommended path).
3. On mismatch or missing file: fail closed with `MODEL_INTEGRITY_FAILED` / `MODEL_LOAD_FAILED`; the app shows plain preview and "Effects unavailable".
4. Verification cost is paid once per process start (hash of a few MB is fast; measured in S2) and the verified result is cached in memory.
5. Load on a background thread before `camera.start` completes the effect path; the preview can start without the effect while the model loads.

## 4. Updates

- MVP: models update only with an app update.
- Future downloadable models (post-MVP, optional): download over HTTPS to app-private storage; verify a signed manifest (public key embedded in the app) and the SHA-256; write atomically (temp file → rename); keep the previous version as a fallback; never load from shared storage or intent-supplied paths. Requires `INTERNET` and therefore a separate, optional feature module + ADR + privacy review; the core must work without it.

## 5. Integrity verification

- SHA-256 of the exact bytes loaded; hash compared in constant time.
- Build-time: script regenerates the manifest; CI-like local check fails if the manifest and the asset disagree.
- Provenance: source URL, retrieval date, license file, and reviewer recorded in [MODEL_CATALOG](MODEL_CATALOG.md) when adopted.

## 6. Offline behavior

All models are available on first launch with no network. There is no first-run download and no model server. If the model cannot be loaded the app degrades to an unstyled but fully functional camera.

## 7. Licensing gate

A model file may enter the repository only after: license text stored, commercial use + redistribution confirmed from the official card/license file, attribution requirements implemented in the Open-Source Licenses screen, and the catalog row updated. Otherwise the model stays out of git.
