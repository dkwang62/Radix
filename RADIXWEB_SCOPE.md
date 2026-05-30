# RadixWeb Scope

Date: 2026-05-24

## Product Role

RadixWeb is a lightweight companion/demo application for the native Radix Swift app.

It should not pursue feature parity with Radix. Its job is to make Radix data portable, inspectable, lightly editable, and exportable in Radix-compatible formats. Radix remains the reference implementation and full-featured product.

## Primary Purpose

RadixWeb should support five core jobs:

1. Import Radix backups.
2. Browse Radix content.
3. Edit a limited subset of user data.
4. Export data back to Radix-compatible backups.
5. Demonstrate the Radix dictionary/browsing experience in a lightweight web environment.

## Permanent Sample Backup

Use `radix_unified_backup.json` in the RadixWeb project root as the permanent sample backup for development, tests, import/export validation, and search compatibility checks.

Current sample characteristics:

- File: `radix_unified_backup.json`
- Schema version: `4`
- Phrases: `123`
- Collections/pages: `24`
- Dictionary data: `dictionary_patch_overlay`
- Profile data: favorites, favorite phrases, prompt config, selected prompt tasks, remembered list, route/home tab/script/search mode/sidebar settings.
- Backup metadata: `backup_id`, `exported_at`, `base_dictionary_fingerprint`, `selected_ai_collection_id`.

This sample remains the default working fixture unless the user restores, imports, or explicitly supplies a different backup copy.

## Approved Scope

### Backup Compatibility

RadixWeb should understand Radix backup/package formats well enough to import and export user-facing data safely.

Approved capabilities:

- Import Radix profile-style JSON.
- Import Radix unified backup JSON.
- Preserve unknown fields where possible.
- Validate schema versions and report unsupported backup contents clearly.
- Support additive import and replace import when safe.
- Export a Radix-compatible backup package.
- Round-trip data without silently dropping fields outside RadixWeb's editable subset.

### Browsing

RadixWeb should browse imported and bundled Radix content.

Approved capabilities:

- Browse dictionary characters.
- Provide search capabilities identical to Radix.
- Search by character, pinyin, English definition, and phrase.
- Support Radix Smart and Definition search modes.
- Support Radix forced-English search behavior (`=` prefix and quoted queries).
- Support Radix-style character result filtering, phrase result merging, pinyin normalization, and strict definition matching.
- Support Radix-compatible script filtering for search results.
- Browse phrases from base and imported/additional phrase data.
- Browse saved pages/collections imported from Radix backups.
- Browse character decomposition, components, derivatives, variants, pinyin, definitions, etymology, notes, and phrases.
- Display stroke order where the existing web/HanziWriter approach supports it.
- Show a lightweight remembered/memory strip for characters and phrases from the active Radix backup.

### Limited Editing

RadixWeb should edit a small, safe subset of Radix user data. It should avoid becoming the full Radix data editor.

Approved editable data:

- Phrase CRUD for user-added phrase data.
- Phrase notes.
- Character notes.
- Saved page/collection metadata and source text.
- Saved page/collection translation reports.
- Phrase selection/deselection within saved pages/collections.
- Favorite flags only if needed for backup compatibility.
- Remembered/memory strip entries only as backup-driven navigation state.
- Prompt/template data only if necessary to preserve or round-trip backups, not as a main workflow.

Not approved as a primary web editing target:

- Full dictionary entry editing.
- Dictionary structural fields such as decomposition, radical, strokes, variants, related characters, and etymology.
- Phrase review workflows.
- AI provider settings or API keys.

### Radix-Compatible Export

RadixWeb should export data that Radix can import.

Approved export targets:

- Radix unified backup JSON.
- Profile-compatible JSON where useful.
- Phrase overlay data represented in the same logical shape as Radix backups.
- Collections/pages represented in Radix-compatible form.
- Collection/page translation reports and phrase selection state represented in Radix-compatible form.
- Character notes represented as dictionary overlay patches or backup fields compatible with Radix.

## Explicitly Out of Scope

These features should not be considered when assessing gaps or planning work:

- OCR.
- Camera capture.
- Full Study memory as a product area. A lightweight backup-driven memory strip is in scope.
- Review systems.
- AI execution.
- Gemini integration.
- API key storage.
- Entitlement/paywall.
- Advanced exports.
- Native mobile parity.
- Search history.

## Priority Order

All roadmap decisions should follow this priority order:

1. Backup compatibility.
2. Radix-identical search capabilities.
3. Phrase CRUD and phrase notes.
4. Character notes editing.
5. Page/collection support, including translation reports and page phrase selection.
6. Radix-compatible export.

## Design Principles

- Prefer compatibility over breadth.
- Preserve data RadixWeb does not understand.
- Keep edits intentionally limited and reversible.
- Make import/export status obvious.
- Treat Swift Radix as the source of truth for schemas and behavior.
- Avoid UI or workflow expansion that makes RadixWeb feel like a replacement for Radix.

## Non-Goals

RadixWeb does not need:

- The full Scan workflow.
- The full Study workflow.
- Native iPhone/iPad/Mac layout behavior.
- Full My Data export catalog.
- Monetization features.
- Direct AI API actions.
- Complete dictionary authoring.

## Success Criteria

RadixWeb is successful when a user can:

1. Import a Radix backup.
2. Search and inspect characters, phrases, and saved pages with Radix-equivalent search behavior.
3. Add or edit user phrases.
4. Add or edit character notes.
5. Make small saved page/collection corrections, including translation reports and selected/deselected page phrases.
6. Use the remembered/memory strip to reopen imported characters and phrases.
7. Export a backup that Radix can import without data loss.
