# RadixWeb Implementation Roadmap

Date: 2026-05-24

Scope basis: `RADIXWEB_SCOPE.md`
Permanent sample backup: `radix_unified_backup.json`

## Goal

RadixWeb is a lightweight companion/demo for Radix. The roadmap is therefore focused on backup compatibility, limited editing, browsing, and Radix-compatible export. It does not pursue feature parity with the Swift app.

Use `radix_unified_backup.json` in the RadixWeb project root as the permanent sample fixture unless the user restores, imports, or explicitly supplies a different backup. The current sample is schema version 4 and includes 123 phrases, 24 collections/pages, profile data, and a dictionary patch overlay.

## Priority Order

1. Backup compatibility.
2. Radix-identical search capabilities.
3. Phrase CRUD and phrase notes.
4. Character notes editing.
5. Page/collection support, including translation reports and page phrase selection.
6. Radix-compatible export.

## Explicit Non-Goals

Do not plan or prioritize:

- OCR.
- Camera capture.
- Study memory.
- Review systems.
- AI execution.
- Gemini integration.
- API key storage.
- Entitlement/paywall.
- Advanced exports.
- Native mobile parity.
- Search history.
- Full Study memory. The lightweight remembered/memory strip remains in scope as backup-driven navigation state.

## Phase 0: Compatibility Foundation

### P0.1 Define Radix Backup Models

Impact: Critical  
Effort: M  
Priority: 1

Add Python models for the Radix data shapes RadixWeb needs to understand.

Models:

- Unified backup package.
- User profile.
- Phrase item.
- Dictionary overlay package.
- Dictionary patch overlay package.
- Collection/page.
- Collection/page translation report fields.
- Collection/page phrase selection state.
- Character notes patch.

Implementation notes:

- Use dataclasses or Pydantic-style validation.
- Preserve unknown fields in imported packages.
- Keep schema-version checks explicit.
- Do not expose all fields in the UI.

Deliverable:

- A compatibility module that can parse a Radix backup and produce an import summary.

### P0.2 Add Working-Copy State

Impact: Critical  
Effort: M  
Priority: 1

Introduce a single working-copy object separate from Streamlit UI state.

Working copy should track:

- Source filename/package type.
- Original imported raw payload.
- Profile data.
- Phrase additions/overrides.
- Character notes overlay.
- Collections/pages.
- Page translation reports.
- Page phrase selection/deselection state.
- Unknown/preserved fields.
- Dirty state.
- Import/export warnings.

Deliverable:

- A central working backup object stored in `st.session_state`.
- Helper functions for update, validation, and export.
- Existing interim implementation already stores `remembered_list` in session/profile state and renders a memory strip.

### P0.3 Backup Import UI

Impact: Critical  
Effort: S-M  
Priority: 1

Add a primary Import Backup workflow.

Capabilities:

- Upload Radix unified backup JSON.
- Upload simple profile JSON.
- Detect package type.
- Validate schema.
- Show import summary: phrases, notes, collections, favorites/profile fields, unsupported preserved fields.
- Choose replace current working copy.

Deferred:

- Additive merge import can wait until the basic replace import is stable.

## Phase 1: Radix-Identical Search

### P1.1 Search Contract Audit

Impact: Critical  
Effort: M  
Priority: 2

Define a web-side search contract from Radix behavior.

Radix behavior to match:

- Smart search.
- Definition search.
- Forced-English search with `=` prefix.
- Forced-English search with quoted queries.
- Character/pinyin/meaning search.
- Exact Chinese phrase lookup.
- Phrase definition search.
- Phrase pinyin search.
- Script filtering for character and phrase results.
- Result ranking and ordering where practical.

Deliverable:

- Search parity checklist with fixtures comparing RadixWeb expected results against Radix behavior.

### P1.2 Search Engine Alignment

Impact: Critical  
Effort: M-L  
Priority: 2

Update RadixWeb search internals to match Radix search.

Capabilities:

- Implement Smart and Definition modes.
- Implement forced-English query parsing.
- Port or mirror Radix pinyin normalization behavior.
- Port or mirror Radix character search ranking.
- Add phrase pinyin index/cache so phrase pinyin search does not scan all rows interactively.
- Search over merged base/imported/user phrase data.
- Apply script filters consistently.

Deliverable:

- RadixWeb search results and ordering match Radix for agreed fixture queries.

### P1.3 Search UI Alignment

Impact: High  
Effort: S-M  
Priority: 2

Expose Radix-compatible search controls without adding out-of-scope state.

Capabilities:

- Smart/Definition mode selector.
- Script filter.
- Result sections matching Radix: characters, smart phrases, definition characters, definition phrases.
- Forced-English query behavior documented through placeholder/help text only if needed.

Non-goal:

- Persisted search history.

## Phase 2: Phrase CRUD

### P2.1 Phrase Overlay Merge Layer

Impact: Very High  
Effort: M  
Priority: 3

Create a phrase repository layer that merges:

- Base `phrases.db`.
- Imported/user phrase additions.

Rules:

- User phrase with same `word` overrides base phrase fields.
- User-only phrase appears in search and browse.
- Hidden/removed review states from imported data should be preserved but not treated as a visible review workflow.
- Phrase notes should be visible/editable.

Deliverable:

- Existing search and phrase display use merged phrase results.

### P2.2 Add Phrase CRUD UI

Impact: Very High  
Effort: M  
Priority: 3

Add focused phrase editing.

Capabilities:

- Add phrase.
- Edit word for new phrases only.
- Edit pinyin.
- Edit English meaning.
- Edit notes.
- View phrase notes wherever phrase details are shown.
- Delete user-added phrases.
- Revert phrase override when the word exists in base `phrases.db`.

Non-goals:

- Review status UI.
- Phrase study workflow.

Deliverable:

- Phrase CRUD changes are reflected in working-copy dirty state and export payload.

### P2.3 Phrase Import/Export Compatibility

Impact: High  
Effort: S-M  
Priority: 3

Ensure imported phrase items preserve fields RadixWeb does not edit.

Capabilities:

- Preserve `added_at`, `review_status`, and `last_reviewed_at`.
- Set `added_at` for newly created web phrases.
- Export phrase list in Radix-compatible unified backup shape.

## Phase 3: Character Notes Editing

### P3.1 Notes Extraction From Imported Backups

Impact: High  
Effort: M  
Priority: 4

Read character notes from imported dictionary overlay or patch overlay data.

Capabilities:

- Detect notes in overlay entries.
- Detect notes in patch overlay metadata.
- Associate notes with character cards.
- Preserve other overlay fields unchanged.

Deliverable:

- Character detail pages show imported notes.

### P3.2 Notes-Only Character Editor

Impact: High  
Effort: S-M  
Priority: 4

Add a safe notes editor on character detail/preview.

Capabilities:

- Edit notes text.
- Clear notes.
- Mark working copy dirty.
- Avoid changing dictionary structural fields.

Non-goals:

- Editing decomposition, radicals, strokes, pinyin, variants, related characters, compounds, or etymology.

Deliverable:

- Notes changes are stored as overlay/patch updates in working-copy state.

### P3.3 Notes Export Compatibility

Impact: High  
Effort: M  
Priority: 4

Export notes in a Radix-compatible dictionary overlay or patch overlay.

Rules:

- Preserve existing overlay content.
- Modify only notes fields for characters edited in RadixWeb.
- If no overlay exists, create the minimal compatible patch/overlay needed.
- Do not export a full rewritten dictionary unless explicitly requested by a developer utility.

## Phase 4: Page / Collection Support

### P4.1 Collection Import and Browser

Impact: High  
Effort: M  
Priority: 5

Import and display Radix saved pages/collections.

Capabilities:

- List pages by name/date.
- Show character count.
- Show source type.
- Show existing translation report when present.
- Show page-associated phrases when derivable from page text or imported metadata.
- Open a page and browse its characters in reading order.
- Preserve duplicate characters in reading-order mode.
- Allow normal character drilldown from page browsing.

Out of scope:

- OCR creation.
- Camera capture.
- Native thumbnail editing.

### P4.2 Collection Light Editing

Impact: Medium-High  
Effort: M  
Priority: 5

Allow limited collection edits.

Capabilities:

- Rename page.
- Edit source text / character sequence.
- Add, edit, view, and clear a page translation report.
- Select/deselect phrases associated with the page.
- Delete page from working backup.
- Toggle favorite only if needed for compatibility.

Preserve:

- IDs.
- Created dates.
- Last viewed dates.
- Source type.
- Thumbnail data.
- Translation reports.
- Hidden phrase words.
- Page phrase selection/deselection metadata.

Deliverable:

- Collection edits round-trip to Radix backup export.

### P4.3 Page Phrase Selection Model

Impact: Medium-High  
Effort: M  
Priority: 5

Add a lightweight page phrase selection layer.

Capabilities:

- Derive candidate phrases from page text using the merged phrase repository.
- Display selected and deselected phrases for a page.
- Let users select/deselect phrases without treating it as a review system.
- Preserve imported hidden/deselected phrase metadata.
- Export selected/deselected state in a Radix-compatible collection shape.

Non-goals:

- Phrase review workflow.
- AI phrase extraction.

### P4.4 Manual Page Creation

Impact: Medium  
Effort: S-M  
Priority: 5

Optional after import/edit works.

Capabilities:

- Paste Chinese text.
- Extract known characters in order.
- Create collection/page.

Non-goal:

- OCR or image capture.

## Phase 5: Radix-Compatible Export

### P5.1 Unified Backup Export

Impact: Critical  
Effort: M-L  
Priority: 6

Export the working copy as Radix-compatible unified backup JSON.

Include:

- Profile.
- Phrase additions/overrides.
- Dictionary notes overlay/patch.
- Collections/pages.
- Page translation reports.
- Page phrase selection/deselection state.
- Selected AI collection ID if imported.
- Preserved unknown fields.

Exclude:

- New API keys.
- Advanced export formats.

Deliverable:

- Radix can import the exported backup.

### P5.2 Export Validation Summary

Impact: High  
Effort: S-M  
Priority: 6

Before download, show:

- Backup schema version.
- Number of phrases.
- Number of character notes.
- Number of collections.
- Number of page translation reports.
- Number of page phrase selections/deselections.
- Preserved unsupported fields.
- Warnings about fields RadixWeb did not understand.

Deliverable:

- User understands whether export is safe.

### P5.3 Round-Trip Tests

Impact: Critical  
Effort: M  
Priority: 6

Add test fixtures for Radix-compatible imports/exports.

Test cases:

- Permanent sample `radix_unified_backup.json` imports successfully.
- Simple profile JSON import/export.
- Unified backup with phrases only.
- Unified backup with dictionary notes.
- Unified backup with collections.
- Unified backup with page translation reports.
- Unified backup with page phrase selection/deselection metadata.
- Unified backup with unknown fields preserved.
- Edit phrase then export.
- Edit phrase notes then export.
- Edit notes then export.
- Edit collection then export.
- Edit page translation report then export.
- Select/deselect page phrases then export.
- Permanent sample round-trips without dropping unknown or unsupported fields.

Deliverable:

- Confidence that RadixWeb does not drop user data.

## Phase 6: UI Reframe

### P5.1 Companion Workflow Navigation

Impact: Medium  
Effort: S-M

Reframe the app around:

- Import.
- Browse.
- Edit Phrases.
- Edit Notes.
- Pages.
- Export.

Existing Search/Browse/Lineage can remain, but the primary workflow should start with backup import and end with compatible export.

### P5.2 De-Emphasize Full Dataset Editing

Impact: Medium  
Effort: S

The current full component-map editor is too broad for the approved scope.

Options:

- Move it under a Developer Tools expander.
- Add warning copy that it is not part of normal Radix backup compatibility.
- Keep it available for internal/demo use only.

## Recommended First Milestone

Build "Import -> Search Parity -> Phrase Edit -> Export" first.

Deliverables:

1. Parse profile JSON and unified backup JSON.
2. Build working-copy state with preserved unknown fields.
3. Match Radix Smart and Definition search behavior.
4. Import phrase additions from backup.
5. Merge base phrases and user phrases.
6. Add phrase CRUD and phrase notes UI.
7. Export unified backup JSON preserving imported data.
8. Add round-trip tests for unknown-field preservation.

Why this milestone:

- It addresses priority 1 and priority 2.
- It creates the data architecture needed for notes and collections.
- It produces a useful companion workflow without expanding scope.

## Second Milestone

Build "Character Notes".

Deliverables:

1. Read notes from imported dictionary overlay/patch overlay.
2. Show notes on character details.
3. Add notes-only editor.
4. Export notes without changing structural dictionary fields.
5. Add round-trip tests.

## Third Milestone

Build "Pages / Collections".

Deliverables:

1. Import saved pages/collections.
2. List and browse pages.
3. Edit name and source text.
4. View/add/edit page translation reports.
5. Select/deselect phrases in pages.
6. Export collections back into unified backup.
7. Preserve thumbnails/reports/hidden phrase metadata.

## Acceptance Criteria

RadixWeb can be considered correctly scoped when it can:

- Import a Radix backup without data loss for unsupported fields.
- Search with behavior identical to Radix.
- Reopen imported remembered characters and phrases from the memory strip.
- Browse imported characters, phrases, and pages.
- Add/edit/delete user phrases.
- View and edit phrase notes.
- Edit character notes only.
- Lightly edit saved pages/collections, including translation reports and page phrase selection.
- Export a backup Radix can import.
- Clearly warn when an unsupported schema or unsafe export condition is encountered.

## Future Considerations

These are acceptable only after the scoped companion workflow is complete:

- Better browsing UI.
- More import diagnostics.
- Optional local file-backed working copies.
- Optional developer-only full dataset tools.

They should not expand into removed scope areas.
