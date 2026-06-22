# Radix portable backup format

Radix backups are UTF-8 JSON and are intentionally independent of SwiftUI,
UIKit, SQLite, and Apple file-provider APIs. iPhone, iPad, Mac Catalyst, and a
future Android client should exchange this document unchanged.

## Current contract: schema 5

- `schema_version`: integer `5`
- `exported_at` and every nested date: ISO-8601 UTC string
- `backup_id`, collection IDs, and selected collection IDs: canonical UUID strings
- JSON field names: stable `snake_case`
- text: Unicode strings; no platform-specific normalization is required
- missing optional fields: treated as absent, not as deletion, during amalgamation

The top-level payload contains:

- `dictionary_patch_overlay`: custom dictionary entries, patches, and deletions
- `phrases`: user phrases and review state
- `profile`: favourites, history, navigation, filters, and AI prompt configuration
- `collections` and `selected_ai_collection_id`: saved pages and current selection
- `api_keys`: optional private AI-provider keys

Because `api_keys` may contain secrets, backup files should be handled as private
user data on every platform.

## Compatibility

Apple clients continue to read schemas 1–4. Those versions encoded dates as
seconds from `2001-01-01T00:00:00Z`; Android should support that epoch only if it
needs to import historical backups. New clients must write schema 5 with ISO-8601
dates and reject versions newer than they understand without modifying local data.

Restore implementations should decode and validate the complete document before
performing writes. A replacement restore should create a recovery snapshot first.
