# Database

SQLite through Drift ([docs](https://drift.simonbinder.eu/)) in the Flutter app. The native engine never opens the database; it returns metadata and Dart persists it (single writer, no cross-process locking).

## 1. Design position

The brief suggested `cartoon_styles`, `transformation_modes`, `recordings`, `app_settings`, `model_assets`, `character_assets`. For the MVP only **two tables** are justified:

| Proposed | MVP decision | Reason |
|---|---|---|
| `recordings` | **`media_items`** (photos and videos) | Needed: gallery metadata |
| `app_settings` | **`app_settings`** | Needed: persisted settings |
| `cartoon_styles` | Not a table | Static catalog shipped in the app (JSON assets + Dart catalog); no user-created styles in MVP. A table would need seeding/migrations for no benefit |
| `transformation_modes` | Not a table | Two or three constants; code enum |
| `model_assets` | Not a table | Models are bundled; the integrity manifest is a JSON asset ([MODEL_ASSET_MANAGEMENT](../models/MODEL_ASSET_MANAGEMENT.md)). Table appears only if models become downloadable (post-MVP) |
| `character_assets` | Not in MVP | Arrives with v2.0 (Mode B) with its own migration |

Media files live in the filesystem (MediaStore); SQLite stores only metadata.

## 2. Entities

### 2.1 `media_items`

| Column | Type | Constraints | Notes |
|---|---|---|---|
| `id` | INTEGER | PRIMARY KEY AUTOINCREMENT | |
| `uuid` | TEXT | NOT NULL UNIQUE | Stable ID for UI/state; generated in Dart |
| `media_type` | TEXT | NOT NULL, CHECK (`media_type` IN ('photo','video')) | |
| `content_uri` | TEXT | NOT NULL UNIQUE | MediaStore `content://` URI returned by the engine |
| `display_name` | TEXT | NOT NULL | e.g. `CamAnime_20261031_134501.jpg` |
| `mime_type` | TEXT | NOT NULL | `image/jpeg`, `video/mp4` |
| `width` | INTEGER | NOT NULL, CHECK (> 0) | Pixels, upright |
| `height` | INTEGER | NOT NULL, CHECK (> 0) | |
| `duration_ms` | INTEGER | NULL; CHECK ((`media_type`='video' AND `duration_ms` > 0) OR (`media_type`='photo' AND `duration_ms` IS NULL)) | |
| `size_bytes` | INTEGER | NOT NULL, CHECK (>= 0) | |
| `style_id` | TEXT | NOT NULL | e.g. `cel_pop`; not an FK (catalog is code) |
| `mode_id` | TEXT | NOT NULL DEFAULT 'mode_a_stylize' | |
| `lens` | TEXT | NOT NULL, CHECK (IN ('front','back')) | |
| `has_audio` | INTEGER | NOT NULL DEFAULT 0, CHECK (IN (0,1)) | Always 0 for photos |
| `engine_version` | TEXT | NOT NULL | Engine build used; for diagnosing look changes |
| `created_at` | INTEGER | NOT NULL | Epoch milliseconds UTC |

Indexes:
- `idx_media_items_created_at` on (`created_at` DESC): gallery order.
- `idx_media_items_type_created_at` on (`media_type`, `created_at` DESC): filtered views (post-MVP filter; cheap now).
- `uuid` and `content_uri` unique indexes are implicit.

### 2.2 `app_settings`

| Column | Type | Constraints |
|---|---|---|
| `key` | TEXT | PRIMARY KEY |
| `value` | TEXT | NOT NULL (JSON-encoded scalar) |
| `updated_at` | INTEGER | NOT NULL (epoch ms) |

Known keys (validated by a typed Dart settings repository; unknown keys ignored):

| Key | Type | Default |
|---|---|---|
| `onboarding.completed` | bool | false |
| `camera.default_lens` | 'back'\|'front' | 'back' |
| `camera.quality_cap` | 'auto'\|'720p'\|'480p' | 'auto' |
| `camera.grid` | bool | false |
| `camera.mirror_front_photos` | bool | false |
| `ui.haptics` | bool | true |
| `perf.mode` | 'auto'\|'saving' | 'auto' |
| `style.last_used` | style id | 'cel_pop' |
| `perm.camera.requested` | bool | false |
| `perm.mic.requested` | bool | false |
| `dev.debug_overlay` | bool | false |

## 3. Relationships

No relationships in the MVP (no foreign keys): two independent tables. Future: `character_assets` (v2.0) referenced by a nullable `character_id` column on `media_items` via an additive migration with a real FK (`ON DELETE SET NULL`).

## 4. Migrations

- `schemaVersion` starts at 1. Every schema change increments it and uses Drift's step-by-step migration helpers; the exported schema JSON for each version is committed under `apps/mobile/drift_schemas/` (generated with the Drift CLI) so tests can verify every upgrade path. Confirm exact commands in the Drift docs at M7 [REF].
- Rule: additive changes preferred; destructive changes require a data-preservation plan and user approval.
- Tests: migration test per version step; open with seeded old-version DB.
- Foreign keys enabled via `PRAGMA foreign_keys = ON` in the Drift setup (no-op until FKs exist). WAL mode default.

## 5. Local storage strategy

| Data | Where | Why |
|---|---|---|
| Photos | `Pictures/Cam-Anime/` via MediaStore | Visible in system gallery |
| Videos | `Movies/Cam-Anime/` via MediaStore | Same |
| Metadata, settings | App-private SQLite (`getApplicationDocumentsDirectory()/camanime.db`) | Not user-visible, excluded from cloud backup (see STORAGE_AND_PRIVACY) |
| Thumbnails | Not persisted; `ContentResolver.loadThumbnail` (API 29) through the bridge, cached in memory by Flutter's image cache | Avoids a thumbnail table and duplicate files |

## 6. Retention and deletion

- No automatic deletion. Items stay until the user deletes them.
- Delete one: engine deletes the MediaStore entry (and file) → on success Dart deletes the row. If the file is already gone, the row is deleted anyway.
- Delete all: engine deletes every URI in `media_items` → rows removed → settings untouched (separate "Reset settings").
- Reconciliation (on gallery open): for each row, check URI resolves; purge rows that don't; files created by the app but missing a row are **not** auto-imported in MVP.
- Rollback: if row insertion fails after a successful capture, the file stays (user data is never silently deleted); a warning is logged and the item appears after the next reconciliation scan of `Cam-Anime` folders [OPEN: implement scan or not in M7].
