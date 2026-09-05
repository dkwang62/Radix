# Radix UI Audit

Audit completed: 2026-09-06. Source baseline: `a1ab08325272cd317d5379eaeadd84b54cfb5710`.

## Executive Assessment

The highest-impact holes are in recovery and mutation semantics, not cosmetic layout. Several screens report success, cancellation, or an exact restore without those guarantees being provided by the underlying stores. A user who encounters one of these failures can lose work while following the application's own recovery instructions.

This is a read-only application audit. No Swift, database schema, persisted identifiers, entitlement policy, or UI implementation was changed. The only repository changes are this report and its link/workstream entry in PROJECT_CONTEXT.md.

**34 findings: 11 High, 21 Medium, 2 Low; no Critical finding established.** Findings are ordered by impact, then likely exposure within each severity. High means loss of saved work, misleading recovery, or loss of access to essential recovery UI. Medium means incorrect results, stranded workflows, accessibility limitations, or conditional reliability failures. Low means lower-impact consistency or validation defects. None of the conditional findings should be described as an observed crash or measured performance regression.

Evidence labels:

- **Probe:** reproduced against the actual compiled RadixCore implementation using disposable SQLite databases and synthetic text. Not a full end-to-end UI reproduction.
- **Source:** a concrete control-to-store trace establishes the faulty behavior; the described UI reproduction still needs execution.
- **Risk:** code establishes a missing protection, but device behavior, timing, or scale determines whether the visible failure occurs.

Simulator work used a fresh iPhone SE (3rd generation), iOS 26.5, named `Radix-UI-Audit-SE`. The user's live library, credentials, purchases, and external AI services were not used. Runtime coverage was targeted, not an exhaustive execution of every control or every possible state. Physical iPad, full VoiceOver, Dynamic Type, background interruption, and large-data UI runs remain required. This report is not release sign-off.

## Application Map And Coverage

### Structure And State

- `RadixApp` constructs the application store and entitlement environment. `RootView` handles welcome, global presentations, URL entry, lifecycle, and transfer actions.
- Compact width uses `RootPhoneView` with a NavigationStack, title navigation menu, global Search/Camera controls, and character-detail destinations. Regular iPad uses `RootDetailPane` with a persistent sidebar; Catalyst uses NavigationSplitView. Width class, route, home tab, selected page, and active previews all affect the visible screen.
- `RadixStore` is a compatibility facade over navigation, collection, study, AI, dictionary, and phrase state owners. SwiftUI views also retain local drafts, selections, pagination, and operation flags. Revisions such as `favoriteSentenceRevision` and `dataImportRevision` drive some, but not all, reloads.
- Persistence spans the base dictionary plus dictionary overlays, the added-phrase SQLite database, `SentenceLibraryStore` SQLite, preference-backed study/practice/AI records, saved-page image files, local checkpoints, database safety copies, and portable backup bundles. These are not one transaction.
- Sentence identity combines UUIDs and a unique normalized Chinese key. Page, practice, and extracted-page references connect records in different stores. Deletion and restore therefore require referential reconciliation, not only removing a visible row.
- AI has manual prompt/copy/paste flows and asynchronous Gemini execution. Capture has Apple Vision plus automatic Gemini fallback. Several Tasks outlive the local selection or view that started them.
- Errors are variously thrown, stored in facade status strings, shown in local alerts, swallowed with `try?`, or converted into an in-memory fallback. That inconsistency is directly visible in the findings below.

### User-Facing Surface Inventory

This inventory records source-level coverage and the controls/transitions examined. It is not a claim that every listed control was tapped in the simulator.

| Surface | Controls and states examined | Principal source families |
| --- | --- | --- |
| Welcome and shell | Start/Skip, title menus, Search/Camera, breadcrumbs, contextual return, compact/detail navigation, sheets, activation and URL entry | App/RadixApp, RootView, RootPhoneView, RootDetailPane, RootSidebar, RootViewSupport, BreadcrumbStrip |
| Browse dictionary | Character tiles, page arrows, script mode, component-first mode, radical/structure/stroke filters, help, preview and full detail | FilterGridTab, BrowseDictionaryGrid, BrowseFiltersSheet, BrowseGridComponents, BrowsePhonePreview |
| Browse saved pages | Source/page picker, sort/favorite menus, image/text grids, image viewing, selection restoration, delete, rename/edit, corrected-page promotion | BrowseSource*, BrowseImage*, BrowseCollectionEditing, BrowseScrollRestoration, RadixStoreCollections |
| Capture | Camera, Album, Files, clipboard, Text to Page, picker cancellation, OCR progress/error/no text, auto-save, free-page boundary | CaptureTab, CaptureWorkbenchViews, CaptureImageIO, CapturedImage, CaptureOCRService, RadixStoreImageOCR |
| Share extension | Image/text selection, extension completion/error, app handoff, repeated activation, pending imports | ShareExtension/ShareViewController, Shared/RadixSharedImageImport, RadixStoreSharedImageImport |
| Search | Text entry/clear/submit, recent searches, examples, result pages, script and phrase-length filters, previews and drill-down | SmartSearch*, SmartResultsGrid, RadixStoreSearch |
| Character inspection | Favorite, notes/edit, pinyin/speech, stroke replay/share, component links, phrase/examples sheets, back/close | CharacterDetail*, CharacterInfoCard*, LightweightCharacterPreviewCard, StrokeOrder*, AppleStrokeViews |
| Roots/components | Root/part navigation, filters, tiles, popovers, selected component, no-character state, origin return | ComponentsExplorer*, ComponentsRootsPopover, ComponentCharacterTile |
| Phrase/sentence inspection | Script/animation controls, favorite, notes Save/Cancel, phrase lookup, example lookup, delete, automatic explanation/improvement | PhraseInfo*, PhraseTableSheet, SentenceExampleListSheet, PracticeSentenceSurface |
| Study pages and favorites | Empty pages/Create Page, sorting, expand/open page, character/phrase grids, favorite changes, checkpoints | FavouritesTab, FavouritesSections, FavouritesStudyGrid*, FavouritesAICleanedPage, FavouritesCheckpoints |
| Study sentences | Source filter, search, minimum length, pagination, select/bulk delete, favorite, edit, source links, practice, database import/export/clear | FavouritesSentence*, FavouritesPresentations, FavouritesTabLifecycle |
| Added phrase review | Status filter, classification tools, tiles, selected preview, page arrows, add, delete/reject confirmations, close | AddedPhraseReview* |
| Practice/review/quiz | Topic/set choice, script, reveal, speech, Again/Good/Easy, answer options, score/next/done, inline inspection | ConversationPractice*, RadixStoreConversationPractice |
| Character/phrase editing | New/edit fields, notes, Save/Cancel, revert/delete, validation, write failure | QuickCharacterEditor*, QuickPhraseEditorView, QuickEdit*, AddPhrase* |
| Page AI workflows | Check OCR, extracted/corrected material, translation report, phrase extraction, manual/automatic selection, paste/apply/save/clear | BrowseImageActions, BrowseCollectionEditing, CapturePhrase*, BrowsePhraseExtractionSheet, BrowseTranslationReportSheet, RadixStore AI extensions |
| AI templates | Task/source selectors, draft fields, Save/reset, test output, copy/open AI, All Templates, task switching | AILinkView, AILinkPrompt*, AILinkTemplateEditor |
| My Data | Device checkpoints, restore/merge file acquisition, previews/counts, export formats, importers/exporters, recovery confirmation/progress/cancel | DataEdit*, DataBackupPreview*, RootViewDataTransfer, RadixStoreDataImport/Export |
| Settings | API/model fields and setup, preferences, optimization, storage health, database safety copies/restore, erase, onboarding reset, references | SettingsView, RadixStoreDataMaintenance, RadixStoreDataEditHelpers |
| Upgrade/reference sheets | Plans, loading/unavailable state, purchase/pending/restore, dismiss, development override, privacy/EULA, glossary/credits/help | Paywall*, EntitlementManager, GlossaryView, CreditsView, RadixInlineHelpDisclosure |

### Runtime Observations And Non-Findings

- Fresh launch, welcome dismissal, dictionary browsing, search for `water`, title-menu navigation to empty Study, and return through global Search were exercised on the SE simulator.
- The suspected stale Search results/query mismatch was **not reproduced**: global Search clears the previous search deliberately. It is excluded from the findings.
- Empty Study exposed a Create Page action. Camera picker cancellation returned to Capture, and cancelling an unsaved manual page returned without creating a page. Those paths were not dead ends in this run.
- On the camera-less simulator, Camera opened the photo-library fallback. This is not evidence that a physical device's camera or permission-denied flow works.
- Album opened Upgrade; plans and a Close control were available. No purchase, Restore Purchases, credential entry, or AI call was performed. Offline/pending payment behavior below is source-derived.
- Several important protections already exist: destructive alerts in normal phrase/sentence review, security-scoped file access, backup size/version/hash checks, safety-copy creation, normalized restored filters, local stroke-data fallback messages, and WebKit bootstrap retry/process-termination handling. These do not remove the narrower failures below.

## High-Priority Findings

### UI-01: A malformed sentence database overwrites good data before restore fails

**Severity:** High. **Evidence:** Probe. **Likelihood:** Conditional on an incomplete or externally produced database.

**Location:** Study Sentences database replacement and backup/database recovery. [SentenceLibraryStore.swift:357](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:357), [SentenceLibraryStore.swift:390](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:390), [FavouritesSentenceTransfer.swift:71](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceTransfer.swift:71).

**How to reproduce:** In a disposable library with two saved sentences, create a SQLite file with only `CREATE TABLE sentence_examples (id TEXT, normalized_key TEXT, record_json BLOB)`. Import it through the sentence database Replace path. The equivalent direct-store probe was executed.

**Expected behaviour:** Reject the incomplete database before touching the live corpus; both existing sentences remain available.

**Likely current behaviour:** Validation accepts the file. Restore copies it into the live database, then throws `no such column: created_at`. The probe's destination went from two sentences to zero.

**Why it happens:** Validation checks only three column names. `sqlite3_backup` changes the destination before `ensureSchema()` verifies that the copied database supports required indexes/columns. Record JSON and semantic consistency are not validated either.

**Recommended fix:** Open and migrate a staging copy, validate full schema, integrity, record decoding and identity constraints, then atomically install it. Keep the live connection/corpus untouched until validation succeeds, and automatically restore the previous database on commit failure.

### UI-02: A failed full backup restore can leave a hybrid of old and new data

**Severity:** High. **Evidence:** Source. **Likelihood:** Conditional on one invalid component or a later write failure.

**Location:** My Data > Restore/Merge Backup. [RadixStoreDataImport.swift:159](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataImport.swift:159), [DataEditRestoreFlow.swift:208](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:208).

**How to reproduce:** Make a structurally valid backup bundle containing a valid, different sentence database and an invalid added-phrase database, with matching manifest hashes. Choose Wipe and Restore. Alternatively inject a phrase-database write failure after sentence import succeeds.

**Expected behaviour:** Either the entire backup is installed or the complete previous state remains; recovery is automatic on failure.

**Likely current behaviour:** Sentences are replaced first. The later phrase import fails, leaving old pages/profile/preferences with new sentences, despite a restore error.

**Why it happens:** Sentence DB, phrase DB and payload mutation are sequential operations without a cross-store commit/rollback boundary. Safety copies exist but are not automatically rolled back. A valid hash establishes bytes, not a usable database.

**Recommended fix:** Validate all components first; stage every store, image set and preference payload; commit using a recoverable transaction journal. On launch, finish or roll back an interrupted restore before opening normal UI.

### UI-03: Cancel Restore can report unchanged data while restoration continues

**Severity:** High. **Evidence:** Source. **Likelihood:** Plausible for large or slow restores.

**Location:** My Data restore progress overlay. [DataEditRestoreFlow.swift:24](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:24), [DataEditRestoreFlow.swift:172](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:172), [DataEditRestoreFlow.swift:278](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:278).

**How to reproduce:** Start a sufficiently large Wipe and Restore or Merge Backup. While the phase is Restoring, tap Cancel Restore, then inspect the library after the background import completes.

**Expected behaviour:** Cancellation stops before mutation, or rolls back and confirms that rollback. A non-cancellable commit phase should say so.

**Likely current behaviour:** The overlay closes with "Your existing data was not replaced," but the import can continue changing data. Its eventual completion/error is ignored.

**Why it happens:** Cancel only clears `restoreOperationID` and local phase. It does not cancel the Task or undo mutations. The operation-ID check occurs after awaited import, not inside the store operations.

**Recommended fix:** Separate cancellable acquisition/validation from a protected commit phase. Own the operation Task, propagate cancellation, and report cancellation only after the system knows what was or was not committed.

### UI-04: Sentence writes can fail silently and hide the existing library

**Severity:** High. **Evidence:** Probe plus source UI trace. **Likelihood:** Conditional on lock, storage, or database failure.

**Location:** Sentence editing/import/favorite/delete paths. [SentenceLibraryStore.swift:216](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:216), [SentenceLibraryStore.swift:234](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:234), [SentenceLibraryStore.swift:273](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:273), [RadixStudyPreferences.swift:370](/Users/desmondkwang/Developer/Radix/Services/RadixStudyPreferences.swift:370), [FavouritesPresentations.swift:68](/Users/desmondkwang/Developer/Radix/App/FavouritesPresentations.swift:68).

**How to reproduce:** Seed two sentences, hold an exclusive SQLite lock from a second connection, and upsert a third through the actual store. Release the lock and reopen. For the UI variant, inject an equivalent save failure while saving a sentence edit.

**Expected behaviour:** Preserve the visible/persisted corpus, leave the draft open, and show a retryable save error.

**Likely current behaviour:** The probe showed only the incoming sentence during the session; reopening showed the original two and lost the apparent new save. Other write paths swallow errors while UI can announce Updated or Deleted. Changing a sentence key also deletes the old record before replacement succeeds.

**Why it happens:** The upsert catch installs only the incoming batch as `fallbackRecords`. Replace/delete are nonthrowing or swallow storage errors, so callers cannot distinguish durable success from failure.

**Recommended fix:** Return a typed persistence result, keep the last known complete corpus on failure, and never label an in-memory-only write as saved. Make key-changing edits atomic and keep drafts available for retry/export.

### UI-05: Editing a sentence into an existing sentence silently destroys the other record

**Severity:** High. **Evidence:** Probe plus source editor trace. **Likelihood:** Plausible during correction and duplicate cleanup.

**Location:** Study > Sentences > Edit. [RadixStudyPreferences.swift:370](/Users/desmondkwang/Developer/Radix/Services/RadixStudyPreferences.swift:370), [SentenceLibraryStore.swift:911](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:911), [FavouritesSentenceEdit.swift](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceEdit.swift).

**How to reproduce:** Save A as "你好。" and B as "再见。", with B favorited and carrying different notes/source links. Edit A's Chinese to "再见。" and Save.

**Expected behaviour:** Warn about the collision or merge deliberately, preserving favorite status, notes, source links and referenced identity.

**Likely current behaviour:** B's UUID and favorite state disappear. The probe left one record with A's identity and no favorite.

**Why it happens:** The facade deletes A's previous key, then `INSERT OR REPLACE` resolves the unique normalized-key collision by replacing B. The editor only validates nonempty content.

**Recommended fix:** Detect normalized-key conflicts before saving. Offer an explicit merge with deterministic identity/reference preservation, or reject the conflicting edit. Perform the whole operation transactionally.

### UI-06: A checkpoint cannot restore the sentence content it appears to protect

**Severity:** High. **Evidence:** Source. **Likelihood:** High when checkpoints are used before sentence editing/deletion.

**Location:** Study checkpoints and pre-restore recovery checkpoints. [RootViewDataTransfer.swift:67](/Users/desmondkwang/Developer/Radix/App/RootViewDataTransfer.swift:67), [RadixStoreDataExport.swift:15](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataExport.swift:15), [RadixStoreDataImport.swift:218](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataImport.swift:218), [DataEditRestoreFlow.swift:242](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:242).

**How to reproduce:** Create a checkpoint containing a saved sentence. Change its text or delete it. Return to that checkpoint, then inspect Sentences and any extracted-page references.

**Expected behaviour:** The checkpoint restores the sentence as it existed when saved, consistent with the confirmation that current study data will be replaced.

**Likely current behaviour:** The old sentence body is unavailable. A changed record may supply its current text; a deleted record's pointer is skipped. The operation can still say Returned to checkpoint.

**Why it happens:** `portableBackupPackage()` omits full sentence/favorite-sentence/cleaned-page rows in favor of pointers. Quick checkpoints serialize only that JSON, not the corresponding sentence database. Restore resolves pointers against today's database.

**Recommended fix:** Capture and restore a version-matched sentence DB with each checkpoint, using the same complete backup contract as portable bundles. Do not present an incomplete JSON snapshot as protection for all study data.

### UI-07: Erase My Data leaves sentence, practice and extracted-page data behind

**Severity:** High. **Evidence:** Source. **Likelihood:** Every reset with these data categories present.

**Location:** Settings > Erase My Data on This Device. [SettingsView.swift:281](/Users/desmondkwang/Developer/Radix/Views/SettingsView.swift:281), [SettingsView.swift:475](/Users/desmondkwang/Developer/Radix/Views/SettingsView.swift:475), [RadixStoreDataEditHelpers.swift:182](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataEditHelpers.swift:182).

**How to reproduce:** Add/favorite sentences, import a practice pack, complete a practice item, and extract sentences from a saved page. Confirm Erase My Data, then revisit Study and reopen the app.

**Expected behaviour:** All current user learning data is erased except the explicitly retained snapshots and API keys.

**Likely current behaviour:** Saved sentences/favorite sentences, imported practice packs/progress and preference-backed extraction records remain. Their owning pages may be gone. Settings nevertheless says My data was erased.

**Why it happens:** Reset clears dictionary/phrase/page/favorite-character/favorite-phrase and prompt state, but does not clear the sentence library and several `RadixStudyPreferences` data families.

**Recommended fix:** Define a single inventory of erasable stores and caches, clear them coherently, invalidate all relevant UI revisions, and verify after reopening. Clearly separate current-data erasure from intentional retention of recovery copies and credentials.

### UI-08: Merge Backup silently overwrites newer page edits with older versions

**Severity:** High. **Evidence:** Source. **Likelihood:** High in ordinary cross-device backup merging.

**Location:** My Data > Merge Backup, saved-page merge. [RadixStoreCollections.swift:37](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:37), [DataEditRestoreFlow.swift:172](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:172).

**How to reproduce:** Back up a page. Change its name, characters, translation or other stored page fields locally. Merge the earlier backup back into the device.

**Expected behaviour:** Preserve newer changes or present a conflict preview. A merge should not silently behave like replacement for matching pages.

**Likely current behaviour:** The incoming page replaces the local page with the same UUID, regardless of which version is newer. The merged result can then be written back to the backup file.

**Why it happens:** The merge dictionary unconditionally assigns `mergedByID[collection.id] = collection`; there is no revision comparison or field-level conflict handling.

**Recommended fix:** Add content revisions and explicit conflict rules. Preserve both versions when ordering cannot be established, show conflicts before commit, and do not overwrite the backup until the user understands the resolution.

### UI-09: Duplicate page UUIDs survive restore and can crash a later merge

**Severity:** High. **Evidence:** Source. **Likelihood:** Low normally; credible with malformed or externally edited backups.

**Location:** Backup restore, Study/Browse page lists, later Merge Backup. [RadixStoreCollections.swift:37](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:37), [RadixStoreCollections.swift:55](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:55), [UnifiedPackage.swift:340](/Users/desmondkwang/Developer/Radix/Models/UnifiedPackage.swift:340).

**How to reproduce:** In a disposable backup, duplicate a valid collection object with the same UUID and known Chinese characters. Wipe and Restore that JSON; then merge another backup containing a collections array.

**Expected behaviour:** Reject or reconcile duplicate IDs before persisting them. Lists should remain selectable and merge should not terminate the app.

**Likely current behaviour:** Duplicate identities reach page lists. The later `Dictionary(uniqueKeysWithValues:)` construction traps on duplicate local UUIDs.

**Why it happens:** `sanitizeCollections` only filters unsupported characters/empty pages. Codec validation does not enforce collection identity uniqueness.

**Recommended fix:** Validate unique identities and reference integrity at import boundaries and startup. Reject ambiguous records or reconcile them with a documented policy; never use a trapping uniqueness initializer on unvalidated persisted input.

### UI-10: Optimize Database can overwrite edits made while it is running

**Severity:** High. **Evidence:** Source race. **Likelihood:** Conditional on overlap with a sufficiently large optimization.

**Location:** Settings/My Data optimization and Study extracted sentences. [RadixStoreDataMaintenance.swift:290](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataMaintenance.swift:290).

**How to reproduce:** Prepare many cleaned-page records needing phrase-link changes. Start Optimize Database. While its detached work runs, edit extracted material or delete one of those pages. Wait for optimization to finish.

**Expected behaviour:** Optimization preserves newer user mutations and cannot resurrect removed artifacts.

**Likely current behaviour:** If optimization changes at least one page, it writes its old full-array snapshot back, potentially discarding edits or restoring deleted cleaned-page records.

**Why it happens:** Records are captured before `await Task.detached`, then the complete result replaces preference state with no revision comparison or per-record merge.

**Recommended fix:** Serialize maintenance with mutations, or apply an ID/revision-checked patch to the current records. Do not replace a mutable store from a stale snapshot.

### UI-11: A startup load error can block the very screens needed to recover

**Severity:** High. **Evidence:** Source. **Likelihood:** Conditional on repository/standard-data load failure.

**Location:** iPad/Catalyst root detail and iPhone startup. [RadixStoreLifecycle.swift:11](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreLifecycle.swift:11), [RootDetailPane.swift:45](/Users/desmondkwang/Developer/Radix/App/RootDetailPane.swift:45), [RootPhoneView.swift:87](/Users/desmondkwang/Developer/Radix/App/RootPhoneView.swift:87).

**How to reproduce:** On a disposable installation, inject a repository-opening failure and relaunch. On iPad/Catalyst try navigating to Settings or My Data; compare compact iPhone behavior.

**Expected behaviour:** A useful load error with Retry, diagnostics, and access to safe export/restore/recovery actions.

**Likely current behaviour:** Regular detail displays Failed to Load before route dispatch, so selecting Settings or My Data cannot reach their recovery UI. Compact phone content does not check the same error and may instead look empty or partially initialized.

**Why it happens:** Error rendering globally replaces detail content; initialization has no user-facing retry/recovery state. The compact shell applies a different policy.

**Recommended fix:** Introduce an explicit startup state and a recovery shell independent of loaded content. Keep Settings, diagnostics and safe recovery accessible on every platform.

## Medium-Priority Findings

### UI-12: Page deletion leaves dangling sentence provenance and descendant practice packs

**Severity:** Medium. **Evidence:** Source. **Likelihood:** High with corrected pages and page-derived study material.

**Location:** Browse/Study > Delete Page and sentence source actions. [RadixStoreCollections.swift:244](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:244), [FavouritesSentenceRows.swift:207](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:207), [FavouritesSentenceRows.swift:271](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:271).

**How to reproduce:** Create a page and corrected descendant, attach a practice pack to the descendant, and save sentences with both deleted-page and surviving-page sources. Delete the original page, then inspect Practice, From Pages and Open Page actions.

**Expected behaviour:** Preserve independent learning memory, remove every deleted page's owned artifacts, and retain navigable links to surviving sources.

**Likely current behaviour:** Descendant pages disappear but their packs can remain; sentence source records still point to deleted pages. A sentence whose first page source was deleted can lose Open Page even when another source survives.

**Why it happens:** Pack deletion tests only the root ID, not the full descendant set. Sentence provenance is not reconciled. Source navigation selects the first page ID rather than the first resolvable source.

**Recommended fix:** Reconcile the full removed-ID set across all stores, distinguish historical provenance from live links, choose surviving sources for navigation, and publish study revisions.

### UI-13: An empty extracted-page section in a full restore does not clear current records

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Common when restoring an earlier, smaller library.

**Location:** Wipe and Restore/checkpoints, extracted-page state. [RadixStoreDataImport.swift:218](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataImport.swift:218).

**How to reproduce:** Save a backup with no extracted pages. Later extract sentences from a page. Wipe and Restore the earlier backup, then inspect extracted-page state and reopen Study.

**Expected behaviour:** Complete restore clears data categories that are empty in the selected backup.

**Likely current behaviour:** Old cleaned-page records remain because the importer returns early for empty/missing references or when no pointers resolve.

**Why it happens:** The early guards do not distinguish additive import from complete replacement.

**Recommended fix:** Give absent, empty and invalid fields explicit version-aware semantics. Complete mode must clear an explicitly empty category; unresolved references should produce a report, not silently retain unrelated current data.

### UI-14: Page-specific sentence queries mix unrelated source relationships

**Severity:** Medium. **Evidence:** Probe. **Likelihood:** Plausible once the same sentence appears in several sources.

**Location:** Page-derived sentence lookup/reconciliation. [SentenceLibraryStore.swift:774](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:774).

**How to reproduce:** Store one sentence with an OCR source on page A and an AI-cleaned source on page B. Query the AI-cleaned sentences for page A, as the page-specific store path does.

**Expected behaviour:** Zero matches: no individual source relationship says AI-cleaned on page A.

**Likely current behaviour:** The probe returns one match, allowing incorrect page-specific results and reconciliation inputs.

**Why it happens:** SQL tests membership in `source_page_ids` independently from the global `has_ai_cleaned_page_source` flag. The predicates can be satisfied by different source entries.

**Recommended fix:** Store/query a normalized source relation or correlated source tuples. Test every combination of page ID and source type across multi-source records.

### UI-15: Unfavoriting the last row of the last sentence page can strand pagination

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary boundary case.

**Location:** Study > Sentences > Favorites. [FavouritesSentenceData.swift:114](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:114), [FavouritesSentenceRows.swift:252](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:252), [FavouritesTabLifecycle.swift](/Users/desmondkwang/Developer/Radix/App/FavouritesTabLifecycle.swift).

**How to reproduce:** Favorite exactly 11 eligible sentences, use the default 10-row page size with no search, choose Favorites, go to page 2, and remove that row's favorite star.

**Expected behaviour:** Move to page 1 and display its ten remaining rows.

**Likely current behaviour:** The query uses the old second-page offset and returns no rows. The index then clamps to zero without querying again. The screen can show no rows and an invalid range such as `1-0 of 10`, with both page arrows disabled.

**Why it happens:** Count and records are loaded before index correction. The favorite action only refreshes local sentence state; there is no page-index observer that guarantees another query.

**Recommended fix:** Requery whenever clamping changes the offset, preferably returning a valid page/count pair atomically. Cover totals 0, 1, 10, 11 and 20, with deletion, unstar and filter changes.

### UI-16: Reopening the phrase notes editor can replace recently saved notes with old text

**Severity:** Medium. **Evidence:** Source. **Likelihood:** High in snapshot-backed phrase sheets.

**Location:** Phrase table > phrase card > Edit Notes. [PhraseInfoHeader.swift:68](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoHeader.swift:68), [PhraseInfoNotes.swift:104](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoNotes.swift:104), [PhraseTableSheet.swift:69](/Users/desmondkwang/Developer/Radix/Views/PhraseTableSheet.swift:69).

**How to reproduce:** Open a phrase inside PhraseTableSheet, edit its notes, Save, and immediately tap Edit Notes again without closing the sheet. Save again or Cancel.

**Expected behaviour:** The second editor opens the just-saved text; Cancel restores that saved value.

**Likely current behaviour:** The editor reloads the original notes. Saving can overwrite the new notes; Cancel can also make the locally displayed notes revert.

**Why it happens:** The card displays `editableNotes` after a successful save but initializes Edit/Cancel from the immutable `phrase.notes`. The parent's selected phrase is a stored value, not a fresh repository lookup.

**Recommended fix:** Maintain one committed local note value or resolve the current phrase by identity. Edit/Cancel should use that committed value, not an older presentation snapshot.

### UI-17: Quick editors delete or revert immediately, unlike equivalent review screens

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary accidental-tap case.

**Location:** Quick character and phrase editors. [QuickCharacterEditorActions.swift:37](/Users/desmondkwang/Developer/Radix/App/QuickCharacterEditorActions.swift:37), [QuickPhraseEditorView.swift:243](/Users/desmondkwang/Developer/Radix/App/QuickPhraseEditorView.swift:243).

**How to reproduce:** Open an added phrase/character in its quick editor and tap Delete, or open a modified built-in entry and tap Revert.

**Expected behaviour:** A consistent destructive confirmation or a reliable, visible Undo, including a clear account of lost edits.

**Likely current behaviour:** The mutation executes and the editor dismisses immediately. In contrast, the normal phrase card and phrase review use confirmation alerts.

**Why it happens:** Quick-editor management buttons call deletion/revert directly; Revert is also visually styled as an ordinary action although it discards edits.

**Recommended fix:** Share a destructive-action contract across editors/review, with appropriate impact text and undo/recovery behavior.

### UI-18: Failed phrase deletion disappears from the UI and can be reported as removed

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Conditional on database failure.

**Location:** Quick Phrase Editor and Add Phrase review. [RadixStoreDataEdit.swift:371](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataEdit.swift:371), [QuickPhraseEditorView.swift:289](/Users/desmondkwang/Developer/Radix/App/QuickPhraseEditorView.swift:289), [AddPhraseSheet.swift:129](/Users/desmondkwang/Developer/Radix/Views/AddPhraseSheet.swift:129).

**How to reproduce:** Inject a write/lock failure in the added-phrase database, then delete an added phrase through one of these screens. Reopen the list/app.

**Expected behaviour:** Keep the phrase visible and show the deletion error in the active screen.

**Likely current behaviour:** In-memory lists change first; the editor dismisses or the candidate is removed despite failure. The phrase can reappear after reload.

**Why it happens:** `removeDataEditPhrase` returns no result, removes list entries before SQLite deletion, and catches errors into a facade status string the caller does not use as its success condition.

**Recommended fix:** Persist first, return a throwing/typed result, update lists after success, and keep the active editor open on failure.

### UI-19: OCR completion can take over navigation after the user has left Capture

**Severity:** Medium. **Evidence:** Source race. **Likelihood:** Plausible with slow recognition or network fallback.

**Location:** Capture > Camera/Album/Files, then global navigation. [CaptureTab.swift:285](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:285), [CaptureTab.swift:316](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:316).

**How to reproduce:** Start recognition on a large image. Before completion, navigate through the global title menu to Study or AI and start another task. Wait for OCR.

**Expected behaviour:** Save the result if that is the stated policy, but preserve the user's newer navigation and offer an Open Page action.

**Likely current behaviour:** Late completion updates the shared capture draft and unconditionally navigates to the newly saved page. There is no explicit cancellation/operation ownership check.

**Why it happens:** Recognition completion and `autoSaveRecognizedImage` do not verify that the same capture operation/context is still active.

**Recommended fix:** Use an operation ID and owned Task; separate durable result delivery from navigation. Only auto-open while the originating capture context remains active.

### UI-20: Share-extension imports have no single-consumer ownership or usable failure state

**Severity:** Medium. **Evidence:** Source race/error trace. **Likelihood:** Plausible on launch/foreground handoff and failed OCR.

**Location:** Share to Radix > app activation/import. [RootView.swift:109](/Users/desmondkwang/Developer/Radix/App/RootView.swift:109), [RootView.swift:161](/Users/desmondkwang/Developer/Radix/App/RootView.swift:161), [RadixStoreSharedImageImport.swift:5](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreSharedImageImport.swift:5).

**How to reproduce:** Share an image while Radix is closed, then rapidly activate/reopen it or deliver the import URL while OCR is still running. Separately share unreadable/non-Chinese content and reopen Radix.

**Expected behaviour:** Each shared item imports once, with a visible failed/retry/discard state when it cannot become a page.

**Likely current behaviour:** Multiple Tasks can read the same pending file before removal and create duplicates. OCR errors are silently skipped and retained for later retry; text imports remove their queued input even when no page is created. The user receives no clear outcome.

**Why it happens:** Pending files are enumerated before an await, with no atomic claim/in-flight set. Error handling and acknowledgement differ between image and text imports.

**Recommended fix:** Use an import queue with stable item IDs, atomic claiming, idempotent creation, explicit completion/error states, and a user-visible retry/discard workflow.

### UI-21: Valid uncommon Chinese is discarded, and some manual pages cannot be saved without explanation

**Severity:** Medium. **Evidence:** Probe plus source validation trace. **Likelihood:** High for names, historical text and uncommon characters.

**Location:** Text to Page, OCR, shared text and page editing. [CaptureModels.swift:120](/Users/desmondkwang/Developer/Radix/Models/CaptureModels.swift:120), [RadixStoreCollections.swift:106](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:106), [BrowseCollectionSheets.swift:12](/Users/desmondkwang/Developer/Radix/Views/BrowseCollectionSheets.swift:12), [CaptureTab.swift:375](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:375).

**How to reproduce:** Enter `㐀𠮷𰻞你好` into a new page. Also try only extension characters, then a U+4E00-U+9FFF character absent from the bundled dictionary.

**Expected behaviour:** Preserve source text, distinguish valid Chinese from dictionary coverage, and explain unsupported characters before Save.

**Likely current behaviour:** The extractor probe retained only `你` and `好`. Extension-only input cannot enable Save. In-range but unsupported input can enable Save, yet `createCollection` returns nil and the sheet remains without an error.

**Why it happens:** Chinese detection accepts only U+4E00-U+9FFF. The UI's Save test differs from the store's additional dictionary-membership filter.

**Recommended fix:** Centralize Unicode-aware validation, preserve original text even when lookup is unavailable, and return a structured supported/unsupported-character result to the editor.

### UI-22: Album/File/Share image orientation is not propagated consistently to OCR

**Severity:** Medium. **Evidence:** Source risk. **Likelihood:** Conditional on EXIF orientation.

**Location:** Album/Files/shared images versus Camera. [CapturedImage.swift:14](/Users/desmondkwang/Developer/Radix/Services/CapturedImage.swift:14), [CaptureImageIO.swift:38](/Users/desmondkwang/Developer/Radix/Services/CaptureImageIO.swift:38), [CaptureOCRService.swift:34](/Users/desmondkwang/Developer/Radix/Services/CaptureOCRService.swift:34).

**How to reproduce:** Import the same Chinese photo as a physically rotated pixel image and as an EXIF-rotated image through Album and Files; compare Camera and preview orientation.

**Expected behaviour:** All paths recognize the same upright content and reading order.

**Likely current behaviour:** Preview can be upright while Vision receives explicit `.up` for data that requires another orientation, degrading OCR or invoking unnecessary AI fallback. Exact OCR impact needs image-fixture execution.

**Why it happens:** The Data initializer defaults orientation to `.up`; the UIImage initializer maps `imageOrientation`. The loader paths use the former and Vision consumes the separate orientation field.

**Recommended fix:** Read EXIF orientation or normalize pixels once at the input boundary. Test all eight orientations and preserve consistent thumbnail/OCR semantics.

### UI-23: Very large images have no pre-decode resource budget

**Severity:** Medium. **Evidence:** Risk; no memory termination was induced. **Likelihood:** Conditional on large scans/panoramas and device memory.

**Location:** Capture Files/Album and Share import. [CaptureImageIO.swift:38](/Users/desmondkwang/Developer/Radix/Services/CaptureImageIO.swift:38), [CapturedImage.swift:14](/Users/desmondkwang/Developer/Radix/Services/CapturedImage.swift:14), [CaptureOCRService.swift:34](/Users/desmondkwang/Developer/Radix/Services/CaptureOCRService.swift:34).

**How to reproduce:** On a disposable small-memory device, import a high-resolution scanned image/panorama while observing memory and responsiveness. Cancel or navigate away during loading.

**Expected behaviour:** Enforce an input budget, downsample for recognition, show progress, and reject impractical images with a retryable explanation.

**Likely current behaviour:** Full file Data and an image representation are loaded before limits; Vision receives original image data. Camera conversion also re-encodes image data. This can cause stalls, memory pressure or app termination at sufficient scale.

**Why it happens:** Thumbnailing limits saved/AI images but does not bound the earlier loading and local OCR pipeline. There is no explicit byte/pixel budget.

**Recommended fix:** Inspect image metadata before decode, cap bytes/pixels, downsample with ImageIO, and make loading cancellable. Measure with real maximum-size fixtures instead of assuming saved thumbnail size bounds peak memory.

### UI-24: No-Chinese OCR is treated as an AI setup/failure problem

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary blank, English-only or unreadable photos.

**Location:** Camera/Album/Files OCR. [RadixStoreImageOCR.swift:9](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreImageOCR.swift:9), [GeminiClient.swift:11](/Users/desmondkwang/Developer/Radix/Services/GeminiClient.swift:11), [CaptureTab.swift:285](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:285).

**How to reproduce:** With no Gemini key, scan an image with no Chinese text. With a key configured, repeat and inspect which processing method is used.

**Expected behaviour:** Clearly distinguish no text, unsupported text, local OCR failure and optional cloud retry. Let the user know before an otherwise local-looking capture escalates to cloud processing.

**Likely current behaviour:** Empty/non-Chinese Vision output automatically falls through to Gemini; without a key the user gets Missing Gemini API key rather than a useful no-Chinese result. With a key, the image is sent automatically and the capture message explains the fallback only afterward.

**Why it happens:** A successful empty recognition and a thrown recognition error share one unconditional fallback path. Settings describes automatic Gemini features generally, but Capture has no per-operation method choice or local-only control.

**Recommended fix:** Model recognition outcomes separately, retain the local result/error, and offer an explicit cloud retry or a clearly disclosed persisted opt-in with local-only mode.

### UI-25: AI template tests can display a previous task's response under a new task

**Severity:** Medium. **Evidence:** Source race. **Likelihood:** Plausible with slow responses and task/source switching.

**Location:** AI > template test panel. [AILinkPromptGeneration.swift:214](/Users/desmondkwang/Developer/Radix/Views/AILinkPromptGeneration.swift:214), [AILinkView.swift:253](/Users/desmondkwang/Developer/Radix/Views/AILinkView.swift:253), [AILinkView.swift:421](/Users/desmondkwang/Developer/Radix/Views/AILinkView.swift:421).

**How to reproduce:** Start a test for task/source A. Switch to B before A completes, and start B's test. Arrange for A to finish last.

**Expected behaviour:** Each result remains associated with its originating task/source; switching cancels or detaches the old result safely.

**Likely current behaviour:** A's response overwrites B's output/status, while resetting the panel permits overlapping requests.

**Why it happens:** Reset clears local flags/output but does not cancel the Task. Completion writes state without comparing the request ID, task or source snapshot.

**Recommended fix:** Own a cancellable request and immutable request context; gate completion by identity and show which task/source produced stored output.

### UI-26: Changing AI templates silently discards unsaved draft changes

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary template editing/navigation.

**Location:** AI task selector and All Templates editor. [AILinkView.swift:338](/Users/desmondkwang/Developer/Radix/Views/AILinkView.swift:338), [AILinkTemplateEditor.swift:91](/Users/desmondkwang/Developer/Radix/Views/AILinkTemplateEditor.swift:91).

**How to reproduce:** Change a template title/body in the main AI editor without Save. Select another task and return. Compare editing through All Templates.

**Expected behaviour:** Preserve drafts or ask Save/Discard before switching. Equivalent template editors should have the same persistence expectations.

**Likely current behaviour:** Task changes reload stored values and discard the draft without confirmation. The All Templates path writes through store bindings instead, so changes there have different Save/Cancel semantics.

**Why it happens:** `loadPromptDraft` assigns over draft fields on selection change; dirty state is not a navigation guard. The alternate editor directly persists edits.

**Recommended fix:** Share one draft/commit model for both editors, preserve drafts by task ID, and handle dismissal/switching explicitly.

### UI-27: Late sentence improvement can populate a different sentence card

**Severity:** Medium. **Evidence:** Source race. **Likelihood:** Conditional on reusing a card while an AI request is active.

**Location:** Sentence card > automatic improvement/explanation, especially the reused sidebar. [PhraseInfoCard.swift:106](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoCard.swift:106), [PhraseInfoSentence.swift:254](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoSentence.swift:254), [PhraseInfoHeader.swift:85](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoHeader.swift:85).

**How to reproduce:** On a reused sidebar sentence card, start improving sentence A, select sentence B before completion, then wait. Inspect displayed Chinese, status, favorite action and phrase links.

**Expected behaviour:** A's result updates A; B's card stays internally consistent.

**Likely current behaviour:** A's late result can set B's `locallyImprovedSentenceItem` and completion status. Favorite actions still use the card's supplied favorite target, potentially acting on a different item from the displayed improvement.

**Why it happens:** The phrase-change observer resets state but not the Task. Completion does not verify sentence identity, and displayed local improvement and action target are separate values.

**Recommended fix:** Key the request and every action to one effective sentence identity, cancel/invalidate work on selection change, and refresh from the committed store record.

### UI-28: Core study text and compact controls do not follow Dynamic Type consistently

**Severity:** Medium. **Evidence:** Source; full accessibility-device validation pending. **Likelihood:** High for users of larger text or reduced dexterity.

**Location:** Pinyin/notes/captions, sentence cards, phrase classification and script controls. [ResponsiveFont.swift:32](/Users/desmondkwang/Developer/Radix/Models/ResponsiveFont.swift:32), [PhraseInfoSentence.swift:309](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoSentence.swift:309), [AddedPhraseReviewGrid.swift:78](/Users/desmondkwang/Developer/Radix/App/AddedPhraseReviewGrid.swift:78), [SentenceExampleListSheet.swift:34](/Users/desmondkwang/Developer/Radix/Views/SentenceExampleListSheet.swift:34).

**How to reproduce:** Set the largest accessibility text size, open phrase notes, sentence cards, example lists and classification, then try pinyin/notes reading and script/tile activation on a small iPhone.

**Expected behaviour:** Essential learning text scales with user settings; controls remain comfortably reachable and content reflows rather than shrinking away.

**Likely current behaviour:** Many captions remain fixed at 13 points; Chinese and classification text use fixed sizes and minimum scaling. Several action surfaces are only 28-34 points high before any effective hit-area enlargement.

**Why it happens:** `ResponsiveFont` uses fixed `.system(size:)` for iOS captions/tiny text, and several primary study surfaces bypass semantic fonts/scaled metrics. Control dimensions are similarly fixed.

**Recommended fix:** Use semantic text styles/scaled metrics, define accessible hit regions separately from visual dimensions, and add large-text layouts for dense tools. Verify VoiceOver labels, reading order, focus restoration and activation on devices; an AX-tree snapshot alone is insufficient.

### UI-29: The phrase classification grid has no vertical overflow escape

**Severity:** Medium. **Evidence:** Layout risk from source; populated-grid device reproduction pending. **Likelihood:** High on small screens with a full page and selected detail.

**Location:** Study > added phrase classification. [AddedPhraseReviewSheet.swift:27](/Users/desmondkwang/Developer/Radix/App/AddedPhraseReviewSheet.swift:27), [AddedPhraseReviewSheet.swift:103](/Users/desmondkwang/Developer/Radix/App/AddedPhraseReviewSheet.swift:103), [AddedPhraseReviewGrid.swift:18](/Users/desmondkwang/Developer/Radix/App/AddedPhraseReviewGrid.swift:18).

**How to reproduce:** Import at least 30 unreviewed phrases, open classification on an SE-size phone, select a phrase so its detail appears, and inspect bottom rows/page controls. Repeat with large text and any supported landscape presentation.

**Expected behaviour:** All tiles and page/close controls remain reachable, with scrolling or a height-aware page size.

**Likely current behaviour:** Ten fixed 34-point rows plus nine 5-point gaps already require 385 points before toolbars, detail, footer and app chrome. The non-scrolling VStack can overflow or compress other controls at insufficient height.

**Why it happens:** Page size depends on device category, not usable height; flexible max-height frames do not make fixed rows scrollable.

**Recommended fix:** Keep essential commands reachable and put the grid in a bounded scroll region, or derive page capacity from available height without measurement/layout feedback loops. Test full pages, not only empty/few-row screenshots.

### UI-30: Upgrade has no in-session recovery for unavailable products or pending purchases

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Conditional on network/StoreKit states.

**Location:** Upgrade plans and Restore Purchases. [EntitlementManager.swift:98](/Users/desmondkwang/Developer/Radix/Services/EntitlementManager.swift:98), [EntitlementManager.swift:134](/Users/desmondkwang/Developer/Radix/Services/EntitlementManager.swift:134), [PaywallPlans.swift:13](/Users/desmondkwang/Developer/Radix/Views/PaywallPlans.swift:13).

**How to reproduce:** Launch when product loading fails, restore connectivity, reopen Upgrade, and try again. Separately simulate an Ask to Buy/pending transaction and repeated plan taps using a StoreKit test configuration.

**Expected behaviour:** Retry reloads plans without restarting. Pending approval has an explicit state; simultaneous purchase attempts are prevented.

**Likely current behaviour:** The unavailable message says try later but offers no Retry/reload path. Product loading is only initiated at manager initialization. Pending is treated like cancellation, and plan buttons are not disabled while a purchase Task is active.

**Why it happens:** Purchase returns Bool rather than an outcome enum; view state only tracks one `purchasingID`. Presentation does not re-request products.

**Recommended fix:** Add retry/refresh, explicit pending/cancelled/failed/restored outcomes, and one active purchase operation. Verify subscription lapse, restore-with-no-purchases and delayed entitlement updates without real transactions.

### UI-31: Changing quiz script allows the same question to be scored again

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary use of the visible script selector.

**Location:** Practice > Quick Quiz. [ConversationPracticeQuizSheet.swift:290](/Users/desmondkwang/Developer/Radix/App/ConversationPracticeQuizSheet.swift:290), [ConversationPracticeQuizSheet.swift:359](/Users/desmondkwang/Developer/Radix/App/ConversationPracticeQuizSheet.swift:359).

**How to reproduce:** Answer a question whose simplified/traditional target differs. Before Next, switch script and answer again. Repeat on further questions; inspect score and saved practice progress.

**Expected behaviour:** Script is a presentation change or an explicit restarted question; one logical question contributes at most one result unless a new attempt is clearly created.

**Likely current behaviour:** Switching clears the answer lock. `answered` is keyed by item ID plus displayed character, so both script variants can contribute to score; every answer also records another practice result.

**Why it happens:** Script changes reset local round/selection without reconciling attempt identity or prior score.

**Recommended fix:** Key scoring by stable session-question ID, keep answer state across script changes, or explicitly restart the attempt with a clear score/progress policy.

### UI-32: Examples sheets eagerly load all matches and do not track later mutations

**Severity:** Medium. **Evidence:** Source/performance risk; no large-corpus timing claim. **Likelihood:** High for common characters in a large sentence library.

**Location:** Character/phrase card > Examples. [PhraseInfoCard.swift:81](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoCard.swift:81), [RadixStudyPreferences.swift:555](/Users/desmondkwang/Developer/Radix/Services/RadixStudyPreferences.swift:555), [SentenceExampleListSheet.swift:6](/Users/desmondkwang/Developer/Radix/Views/SentenceExampleListSheet.swift:6).

**How to reproduce:** Import a large corpus containing a common character such as 的. Open its Examples sheet. Open/edit/delete an example through a related card and return to the still-present list where that navigation is available.

**Expected behaviour:** Prompt first-page display with progressive loading; list contents refresh after mutations; an empty result has an explanation.

**Likely current behaviour:** Sheet construction synchronously resolves every matching record, then holds a static array. A LazyVStack does not defer that database work. Large lists can stall presentation, stale rows can remain, and zero rows produce a blank scroll surface.

**Why it happens:** Callers request `limit: nil`; exact lookup loops through all query pages before returning. The sheet has no query/revision ownership or empty-state branch.

**Recommended fix:** Reuse paged sentence-query state, load off the presentation path, refresh on corpus revisions and show a meaningful no-examples state.

## Low-Priority Findings

### UI-33: New page names are silently truncated although the creation field accepts more

**Severity:** Low. **Evidence:** Source. **Likelihood:** Ordinary long names.

**Location:** Text to Page > New Saved Page versus Edit Saved Page. [BrowseCollectionSheets.swift:13](/Users/desmondkwang/Developer/Radix/Views/BrowseCollectionSheets.swift:13), [BrowseCollectionSheets.swift:49](/Users/desmondkwang/Developer/Radix/Views/BrowseCollectionSheets.swift:49), [SavedPageRules.swift:4](/Users/desmondkwang/Developer/Radix/Models/SavedPageRules.swift:4).

**How to reproduce:** Create pages named `Chapter One Morning` and `Chapter One Evening`, each with recognized Chinese text. Compare saved names with the entered names, then open Edit Saved Page.

**Expected behaviour:** Preserve names or show/enforce the limit before saving, consistently in creation and editing.

**Likely current behaviour:** Both can be reduced to the same first 11 characters without advance explanation. Only the edit form discloses/enforces the limit.

**Why it happens:** Creation binds the unrestricted string, but storage uses `SavedPageRules.displayName` with an 11-character prefix.

**Recommended fix:** Share name validation and visible length policy between forms; preserve full names if the short-name rule is only a display concern.

### UI-34: The same stored object and recovery action have conflicting user-facing names

**Severity:** Low. **Evidence:** Source and targeted simulator observation. **Likelihood:** High for new users moving between areas.

**Location:** Welcome, title navigation, page editors, Settings and recovery. [RootPhoneView.swift:31](/Users/desmondkwang/Developer/Radix/App/RootPhoneView.swift:31), [BrowseCollectionSheets.swift:60](/Users/desmondkwang/Developer/Radix/Views/BrowseCollectionSheets.swift:60), [SettingsView.swift:225](/Users/desmondkwang/Developer/Radix/Views/SettingsView.swift:225), [RootViewDataTransfer.swift:67](/Users/desmondkwang/Developer/Radix/App/RootViewDataTransfer.swift:67).

**How to reproduce:** Follow Welcome's My Data guidance, navigate through the Data title/menu, create a text-only saved page and edit it, then compare checkpoint/device snapshot/dated-copy wording across Study and Settings.

**Expected behaviour:** Stable names make it clear which objects/actions are equivalent and which recovery artifacts have different coverage.

**Likely current behaviour:** My Data/Data, saved page/Image, and checkpoint/snapshot/dated copy overlap without a clear distinction. The editor calls a text-only page Image. This compounds the incomplete-checkpoint issue rather than explaining its scope.

**Why it happens:** View-local strings remain alongside shared glossary/copy types; historical persistence terminology leaks into UI.

**Recommended fix:** Use the product model's canonical terms centrally and explicitly distinguish full checkpoints, per-database safety copies and portable backups. Review destructive verbs and success messages against their actual storage guarantees.

## Reproduced Probe Evidence

The harness linked the existing debug RadixCore object files and SQLite, injected identity simplification and normal record canonicalization, and wrote only to a fresh temporary directory. The edit probe executes the same delete-old-key/replace sequence as the facade; it does not claim to exercise SwiftUI or every production preprocessing closure.

```text
Locked upsert visible count: 1 (previously 2)
Reopened persisted count: 2
Edit collision: count=1, B exists=false, favorite=false
Three-column malformed database: VALIDATION ACCEPTED
Restore failed after copying: Failed to create sentence schema: no such column: created_at
Restore destination size: 0 (previously 2)
Capture rare Chinese: ["你", "好"]
Page A AI-cleaned query returned 1 (expected 0)
```

Reproduction fixture definitions:

- **Locked upsert:** seed two records with `replaceAll`; open a second SQLite connection and `BEGIN EXCLUSIVE`; upsert one new record; compare `fetchAll` before and after rollback/reopening.
- **Collision:** A has text 你好。 and A notes; B has text 再见。, B notes and favorite=true. Change A's Chinese to B's text; delete A's old normalized key, then replace A. Assert both identities/metadata are accounted for.
- **Malformed restore:** create only the three-column table shown in UI-01; validate it, restore over a two-row store, catch the error, then count the destination.
- **Unicode:** call `CaptureTextExtractor.allCharactersInOrder(in: "㐀𠮷𰻞你好")`.
- **Source correlation:** one record, two sources: `(pageA, ocrSource)` and `(pageB, aiCleanedPage)`; query `.page(pageA, .aiCleanedPage)` and assert zero.

These should become permanent regression tests during the fix pass. They are audit fixtures, not a reason to run destructive fault injection against a real library.

## Remaining Adversarial Test Matrix

The source review identifies failures above, but the following runtime coverage remains open. No unexecuted row should be reported as passed.

| Area | Required device/fixture execution |
| --- | --- |
| Data cardinality | Zero/one/many pages; 99/100/101 free-page attempts; deleted pages versus cumulative quota; 10/11 and 50/51 sentence boundaries; 30/31 classification phrases; duplicate UUID/key imports |
| Scale | Thousands of pages, very long page text/notes/phrase lists, common-character corpus lookups, maximum accepted backup size, high-pixel-count images; record main-thread stalls and peak memory |
| Recovery | Interrupted restore between each store, force-quit/relaunch, cancellation during acquisition versus commit, inaccessible iCloud URL, disk full, SQLite busy/corrupt/partial JSON, old schemas and unresolved source pointers |
| Lifecycle | Repeated enter/leave, background/foreground during OCR/AI/restore/optimization, two overlapping imports, URL handoff during cold initialization, restored/deleted current selection |
| Capture | Real camera allow/deny/restricted, missing camera, limited Photos access, picker Cancel, file-provider cancellation, blank/English/vertical Chinese images, all EXIF orientations, rare Han and mixed-script text |
| AI | Missing/invalid key, offline/timeout/rate limit, malformed/truncated output, cancellation, source deletion/change before response, manual/automatic feature parity; use synthetic material and mocks |
| Accessibility | Small iPhone and physical iPad, largest Dynamic Type, VoiceOver focus/labels/actions, Switch Control, keyboard shown/hardware keyboard, Reduce Motion, contrast in light/dark modes |
| Layout | Full classification page with preview, long Chinese/pinyin/English labels, supported landscape, safe areas, iPad regular-width split/Stage Manager windows and transitions to compact |
| Commerce | Product-load failure/retry, pending/cancelled/failed/restored purchases, expired subscription, legacy entitlement migration, quota enforcement across Camera/Text/clipboard/share routes; StoreKit test environment only |
| Media/reference | Missing source-image file, unavailable stroke data, WebKit termination, speech interruption/audio-session recovery, animation sharing cancellation, glossary/help/credits close and return |

Two particularly important unresolved risks are the regular iPad sidebar's minimum 320-point width before the shell switches to compact, and whether every source-creation entry point applies the same cumulative free-page policy. Both need a policy/device-specific check rather than an invented failure claim. Legacy dated-copy purchase recognition also needs a real historical-entitlement fixture before declaring a regression.

## Fix Order And Maintainability Recommendation

1. **Restore and persistence contract:** UI-01 through UI-07 and UI-09. Introduce staged validation, atomic/recoverable mutation, throwing results and honest progress/cancellation. Lock these guarantees down before further sentence-store restructuring.
2. **Identity and concurrency:** UI-08, UI-10 and UI-12 through UI-20. Centralize mutation/revision publication and reconcile references. Tie asynchronous work to operation and subject identity.
3. **Workflow correctness:** UI-21 through UI-27, UI-30 and UI-31. Unify input validation, image preparation, drafts and asynchronous result presentation.
4. **Accessibility and scale:** UI-28, UI-29 and UI-32, followed by the complete physical-device matrix. Then resolve UI-33/UI-34 copy and validation inconsistencies.

A wholesale UI rewrite or broad "defrag" is not supported by this evidence. Existing screen/component boundaries are usable. Focused consolidation is warranted around sentence mutations, backup/restore coordination, source-reference cleanup, shared import ownership and AI request lifecycle. Moving methods into smaller files without strengthening those contracts will not fix these bugs.

## Verification

- Five focused disposable RadixCore probes executed; results are recorded above.
- Fresh SE simulator launch and the targeted navigation/cancellation/Upgrade flows described above executed.
- Baseline package tests and Catalyst build: see the completion result recorded in PROJECT_CONTEXT.md for this audit work unit.
- No physical-iPad gate, live-cloud-AI test, real purchase, exhaustive accessibility pass, or large-library UI performance certification was completed.
