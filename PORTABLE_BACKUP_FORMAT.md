# Radix Portable Backup Format

Radix writes portable backups as `.radixbackup` files. A current backup is an
uncompressed ZIP bundle containing a platform-neutral JSON payload and, when
available, copies of the sentence and added-phrase SQLite databases. Legacy
standalone JSON backups remain readable.

This document describes the interchange contract, not the same-device
Checkpoint format or the Advanced Pro exports.

## Bundle Contract: Schema 1

A current bundle contains:

- `manifest.json`: bundle schema, generation date, entry sizes, and SHA-256
  hashes;
- `backup.json`: the required portable JSON payload;
- `sentence_examples.sqlite`: optional Sentence Library database;
- `phrases_add.sqlite`: optional added-phrase database.

The manifest identifies every included entry. Restore verifies paths, sizes,
hashes, and database validity before mutating live data. Current bundles are
limited to 750 MiB. Radix's ZIP reader accepts stored entries only; compressed
or streaming-descriptor ZIPs are not part of this contract.

## JSON Payload Contract: Schema 6

- `schema_version`: integer `6`
- `exported_at` and every nested date: ISO-8601 UTC string
- `backup_id`, collection IDs, and selected collection IDs: canonical UUID strings
- JSON field names: stable `snake_case`
- text: Unicode strings; no platform-specific normalization is required
- missing optional fields: interpreted according to schema and restore mode;
  schema-6 complete restore treats a missing extracted-page section as empty

The top-level payload contains:

- `dictionary_patch_overlay`: custom dictionary entries, patches, and deletions
- `phrases`: user phrases and review state
- `profile`: favourites, history, navigation, filters, and AI prompt configuration
- `collections` and `selected_ai_collection_id`: saved pages and current selection;
  a collection may carry its source JPEG so backups and checkpoints remain
  self-contained even though live Radix storage keeps images in separate files
- `extracted_sentence_page_references`: lightweight links from saved pages to
  rows in the bundled sentence database; every schema-6 reference must resolve
  during complete-restore preflight
- `api_keys`: optional private AI-provider keys

Because `api_keys` may contain secrets, backup files should be handled as private
user data on every platform.

## Compatibility

Radix continues to read JSON payload schemas 1–5. Schemas 1–4 encoded dates as
seconds from `2001-01-01T00:00:00Z`; Android should support that epoch only if it
needs to import historical backups. New clients must write schema 6 with ISO-8601
dates and reject versions newer than they understand without modifying local data.

Restore implementations must decode and validate the complete document before
performing writes. Complete restore uses a durable rollback journal containing
the pre-restore payload, both databases, and page images. Caught failures and
startup recovery replay that rollback before normal data access resumes.

Additive restore retains merge semantics and does not treat absent optional data
as a request to erase live categories. Complete schema-6 restore treats included
replacement categories as authoritative, including an empty set of AI-cleaned
pages and their sentence provenance.
