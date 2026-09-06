# Radix UI Audit

Initial audit completed: 2026-09-06. Source baseline: `a1ab08325272cd317d5379eaeadd84b54cfb5710`.
UI-first follow-up: 2026-09-06, on the same application code, after documentation commit `c56a396`.
Repeated-implementation comparison: 2026-09-06, on unchanged application code after documentation commit `62367c9`.
Persistence remediation pass: 2026-09-06, addressing UI-01 through UI-07.

## Executive Assessment

The highest-impact holes are in recovery and mutation semantics, not cosmetic layout. Several screens report success, cancellation, or an exact restore without those guarantees being provided by the underlying stores. A user who encounters one of these failures can lose work while following the application's own recovery instructions.

The audit itself was read-only. A subsequent focused remediation pass changed persistence and recovery implementation for UI-01 through UI-07; no persisted identifier, backup field, entitlement policy, or unrelated feature was changed.

**46 findings: 12 High, 28 Medium, 6 Low; no Critical finding established.** Findings are grouped by severity. Original IDs are preserved; UI-35 through UI-40 came from the UI-first pass and UI-41 through UI-46 from the repeated-implementation comparison. High means loss of saved work, misleading recovery, or loss of access to essential recovery UI. Medium means incorrect results, stranded workflows, accessibility limitations, or conditional reliability failures. Low means lower-impact consistency or validation defects. None of the conditional findings should be described as an observed crash or measured performance regression.

Evidence labels:

- **Probe:** reproduced against the actual compiled RadixCore implementation using disposable SQLite databases and synthetic text. Not a full end-to-end UI reproduction.
- **Source:** a concrete control-to-store trace establishes the faulty behavior; the described UI reproduction still needs execution.
- **Risk:** code establishes a missing protection, but device behavior, timing, or scale determines whether the visible failure occurs.
- **UI-observed:** the stated interaction or visual ambiguity was observed in the isolated simulator and subsequently traced to source; this is not physical-device or full VoiceOver certification.

## Persistence Remediation Status

| Finding | Status after focused fix | Verification/residual boundary |
| --- | --- | --- |
| UI-01 | Addressed. Sentence imports now require SQLite integrity, the complete migratable base schema, decodable records and matching stored IDs/keys before live replacement. Restore also keeps a rollback database until post-copy schema setup succeeds. | A malformed three-column database is rejected and a two-record destination remains unchanged in a permanent test. |
| UI-02 | Addressed for caught failures. Full restore validates both embedded databases before mutation, captures the current full document, and automatically applies it on any subsequent failure. | Abrupt process termination during commit still requires lifecycle/fault-injection testing; there is not yet an on-launch transaction journal. |
| UI-03 | Addressed. Cancel is available only during acquisition/validation, before mutation. The commit overlay states that verified commit cannot safely be cancelled and provides no false cancellation action. | Large real-device restore timing remains in the adversarial matrix. |
| UI-04 | Addressed for active mutation paths. Sentence writes throw without replacing the readable corpus with incoming-only fallback data. Edit, favorite, delete, practice import, AI import and restore paths publish failure instead of success; maintenance records a retry/optimization need. | Read-only SQLite failure behavior and disk-full UI execution still need device/fault-injection coverage. |
| UI-05 | Addressed. Updates use conflict-safe SQL, normalized-key collisions are rejected before dependent artifacts/favorites change, and the edit sheet stays open with the error. | The permanent collision test preserves both IDs and the existing favorite. A future explicit merge UI is optional, not required for data safety. |
| UI-06 | Addressed for newly created checkpoints. Checkpoints now bundle sentence and added-phrase databases and restore through the full-document path. Existing JSON checkpoints remain discoverable and show a limited-scope warning before restore. | New-bundle end-to-end restore needs device execution; old checkpoints cannot retroactively contain missing sentence bodies. |
| UI-07 | Addressed. Erase My Data clears sentence/favorite-sentence data, practice packs/progress, page phrase extractions, cleaned pages and the latest AI result, resets their live selections/revisions, and retains snapshots/API keys as stated. | Store-owner tests verify all practice/artifact preference keys are removed; Settings reset still needs a launch/reopen UI test. |

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

### UI-First Follow-Up Method And Deduplication

The follow-up started from the interface, collecting first-use expectations before reopening this report or tracing implementation details. The same isolated SE simulator was reused with no user library or credentials; it was not a freshly reset installation. The walkthrough covered dictionary controls, filtering, a character card, Notes, the learning-tier guide, phrase lookup, starring a character and finding Favorites, the empty Conversation Practices flow, its Generate Practice Pack handoff, and Text to Page. It does not establish that every remaining screen/control was exercised.

Only six distinct issues were retained. In particular:

- UI-35 is normal-size character-editor layout at the default sheet detent, not UI-28's Dynamic Type behavior or UI-29's classification-grid overflow.
- UI-36 is a missing return to phrase results, not UI-16's stale phrase-note value or the deliberate top-level title-menu navigation model.
- UI-37 is an unsolicited local clipboard read, not UI-24's automatic cloud OCR fallback.
- UI-38 concerns an unlabeled quantity/action; UI-34 concerns inconsistent names for the same object. The observed `6 strokes` and `7` do **not** establish conflicting stroke data.
- UI-39 is compact adaptation of a specific help popover without a visible dismissal control, not a general inaccessible-font claim.
- UI-40 concerns discovering the empty text-entry field, not UI-21's Unicode/Save validation or UI-33's page-name limit.

The Dictionary chevron initially resembled source selection but behaved as an ordinary disclosure, so it was not added as a defect. Active filters visibly showed a count and Reset; Favorites was reachable from the Study menu. These were also excluded. Unicode entry through the simulator automation did not complete reliably, and the Simulator window later became unavailable to the UI tool; neither limitation is attributed to Radix. No page was saved in that attempt. No external AI request or purchase was made.

## Repeated UI Concept Comparison

This pass searched repeated controls and mutation/navigation helpers, followed their callers, and compared active implementations before checking the existing findings. It is a source comparison, not a new simulator walkthrough. Similar names do not establish equivalent semantics, and uncalled helpers are not counted as live UI defects.

| Concept | Implementations compared | Divergence and disposition |
| --- | --- | --- |
| Delete saved page | [Capture callback](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:237), [Browse alert](/Users/desmondkwang/Developer/Radix/App/FilterGridTab.swift:227), [Study alert](/Users/desmondkwang/Developer/Radix/App/FavouritesPresentations.swift:218) | Same store deletion, but only Browse/Study request confirmation and show collateral impact. **New UI-41.** |
| Single-entry delete/revert | [Quick Phrase Editor](/Users/desmondkwang/Developer/Radix/App/QuickPhraseEditorView.swift:243), [phrase card](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoCard.swift:86), [review](/Users/desmondkwang/Developer/Radix/App/AddedPhraseReviewSheet.swift:140) | Immediate mutation/dismissal versus an explicit alert. Already **UI-17/UI-18**; not counted again. |
| Bulk destructive action | [backup preview Revert All](/Users/desmondkwang/Developer/Radix/App/DataBackupPreviewActions.swift:4), [review bulk alerts](/Users/desmondkwang/Developer/Radix/App/AddedPhraseReviewSheet.swift:150), [sentence bulk menu](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceControls.swift:178) | Informational backup preview contains immediate live-library reversion, whereas review/sentence tools confirm destructive batches. **New UI-42.** |
| Editor draft versus saved value | [translation sheet](/Users/desmondkwang/Developer/Radix/Views/BrowseTranslationReportSheet.swift:38), [Browse handlers](/Users/desmondkwang/Developer/Radix/App/BrowseImageActions.swift:141), [Study handlers](/Users/desmondkwang/Developer/Radix/App/FavouritesStudyGridData.swift:231), [Notes actions](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoNotes.swift:55) | Both translation entry points share UI but duplicate the same mixed semantics: typing/Paste need Save; Clear persists immediately. Notes uses a draft/Save/Cancel contract. **New UI-43**; stale note reopening remains **UI-16**. |
| Sentence favorite/edit propagation | [list favorite](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:252), [list edit](/Users/desmondkwang/Developer/Radix/App/FavouritesPresentations.swift:65), [card favorite](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoHeader.swift:85), [store favorite](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreConversationPractice.swift:422) | List writes go straight to preferences and refresh local screen state; card writes publish the shared revision. **New UI-44** covers favorite parity; edit uses the same bypass and needs the same live-preview regression coverage. |
| Search/filter composition | [sentence search](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceControls.swift:25), [sentence query](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:94), [dictionary search](/Users/desmondkwang/Developer/Radix/App/SmartSearchTab.swift:94) | Sentence typing resets source to All even though the query supports source plus text; changing minimum length preserves source. Dictionary search preserves its script filter. **New UI-45.** Submit-based dictionary search versus live sentence filtering is otherwise a reasonable difference. |
| Empty versus no matches | [sentence list](/Users/desmondkwang/Developer/Radix/App/FavouritesSections.swift:99), [Search no-results](/Users/desmondkwang/Developer/Radix/App/SmartSearchResults.swift:29), [Examples sheet](/Users/desmondkwang/Developer/Radix/Views/SentenceExampleListSheet.swift:12) | Sentences says to import data for both an empty corpus and zero filtered matches; Search names the query. **New UI-46.** The static/possibly blank Examples sheet is already **UI-32**. |
| Inspection selection versus bulk selection | [sentence row](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:4), [selection buttons](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:62), [pagination/query refresh](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:75) | Highlight uses the inspected practice-item ID, while checkmarks use a UUID set. Changing page clears the set; refresh intersects it with visible IDs. Bulk selection is page-local. No additional proven defect; test whether users mistake the retained inspection highlight for a selected deletion target or expect cross-page selection. |
| Page-opening navigation | [Capture open](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:233), [sentence Open Page](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:298), [Browse title menu](/Users/desmondkwang/Developer/Radix/App/RootViewSupport.swift:292), [shared destinations](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreNavigation.swift:301) | Capture/Open Page go to page Study; explicit Browse goes to source inspection. Both select the same page ID and can preserve origin. **Intentional per UI_INTENT**, not a reason to merge the destinations. Phrase-result return remains **UI-36**. |
| Page creation and quota | [Capture gates/count](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:357), [shared-image/text import](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreSharedImageImport.swift:5) | Capture checks/increments the cumulative free allowance; share ingestion has no equivalent check/count. This is a concrete policy divergence, but whether Share is intentionally exempt remains unresolved. **Policy decision/test required; not a new entitlement-bypass finding.** |
| Image/OCR errors and cancellation | [Capture](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:285), [share ingestion](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreSharedImageImport.swift:13) | Capture displays errors/status; share ingestion catches and continues without per-item feedback. Shared OCR service does not imply equivalent task ownership. Already **UI-19/UI-20/UI-22 through UI-24**. |
| Restore progress and interaction blocking | [My Data overlay](/Users/desmondkwang/Developer/Radix/App/DataEditRestoreFlow.swift:24), [sentence transfer](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceTransfer.swift:67), [sentence tools disablement](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceControls.swift:132) | My Data uses a local blocking overlay and Cancel; sentence import uses status plus disabled tools, without equivalent cancellation or whole-surface blocking. False cancellation is already **UI-03**. Concurrent row mutations/navigation during transfer need runtime testing; no newly observed race is claimed. |
| Recovery payloads | [quick checkpoint](/Users/desmondkwang/Developer/Radix/App/RootViewDataTransfer.swift:68), [portable package](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataExport.swift:15), [sentence-library package](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataExport.swift:40), [database snapshot restore](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataExport.swift:146) | Checkpoint JSON contains sentence references; dedicated sentence export includes bodies; database snapshots restore one store. Already **UI-01/UI-02/UI-06/UI-34**. Names and UI guarantees must state the payload, not treat these as interchangeable recovery actions. |
| Source/reference cleanup | [page deletion](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:244), [sentence deletion](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:187) | Page deletion cascades some artifacts but does not use the sentence-level reconciliation path. Already **UI-12/UI-13**; cross-source query matching remains **UI-14**. |
| Repeated-looking wrappers | [practice save wrapper](/Users/desmondkwang/Developer/Radix/App/FavouritesTab.swift:294), [store implementation](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreConversationPractice.swift:79) | The view delegates to the store. This is an aligned wrapper, not independent persistence logic needing another extraction. |
| Dormant duplicate source UI | [source-picker branch](/Users/desmondkwang/Developer/Radix/App/BrowseSourceBar.swift:9), [initial flag](/Users/desmondkwang/Developer/Radix/App/FilterGridTab.swift:36), [legacy camera entry](/Users/desmondkwang/Developer/Radix/App/BrowseCollectionEditing.swift:64), [backup delete helper](/Users/desmondkwang/Developer/Radix/App/DataBackupPreviewActions.swift:43) | Repository search found no path setting `showBrowseSource` true and no callers of `beginBrowseCameraScan` or `deleteBackupSavedPage`. The legacy camera/free-page gates and title-based practice fallback disagree with active ID/policy paths, but these are **dormant drift candidates**, not additional user-facing findings. Verify reachability before deleting or reconnecting them. |

Deduplication: UI-41 concerns a saved-page cascade entry point, not UI-17's single-entry editor. UI-42 concerns bulk mutation from an informational backup preview, with a batch predicate separate from the displayed list. UI-43 concerns premature persistence, not stale reopening. UI-44 concerns cross-view invalidation, not UI-15's pagination clamp. UI-45 concerns source-filter reset, not UI-14's SQL source correlation or the previously excluded Search query mismatch. UI-46 concerns filtered-empty messaging, not UI-32's static Examples sheet.

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

**Remediation status (2026-09-06):** Addressed with an explicit non-destructive merge policy. Saved-page content mutations now record an optional `contentModifiedAt` timestamp. A matching incoming page replaces local content only when its timestamp is newer; an older backup keeps the newer local page. Viewing dates and transport-only embedded image bytes do not create content conflicts. Differing legacy/equal-timestamp records are rejected during preflight before databases, payload state or the selected backup file are changed, with an error identifying the conflicting page. Focused coverage verifies older-local preservation, newer-incoming adoption, transport equivalence and ambiguous-conflict rejection.

### UI-09: Duplicate page UUIDs survive restore and can crash a later merge

**Severity:** High. **Evidence:** Source. **Likelihood:** Low normally; credible with malformed or externally edited backups.

**Location:** Backup restore, Study/Browse page lists, later Merge Backup. [RadixStoreCollections.swift:37](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:37), [RadixStoreCollections.swift:55](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:55), [UnifiedPackage.swift:340](/Users/desmondkwang/Developer/Radix/Models/UnifiedPackage.swift:340).

**How to reproduce:** In a disposable backup, duplicate a valid collection object with the same UUID and known Chinese characters. Wipe and Restore that JSON; then merge another backup containing a collections array.

**Expected behaviour:** Reject or reconcile duplicate IDs before persisting them. Lists should remain selectable and merge should not terminate the app.

**Likely current behaviour:** Duplicate identities reach page lists. The later `Dictionary(uniqueKeysWithValues:)` construction traps on duplicate local UUIDs.

**Why it happens:** `sanitizeCollections` only filters unsupported characters/empty pages. Codec validation does not enforce collection identity uniqueness.

**Recommended fix:** Validate unique identities and reference integrity at import boundaries and startup. Reject ambiguous records or reconcile them with a documented policy; never use a trapping uniqueness initializer on unvalidated persisted input.

**Remediation status (2026-09-06):** Addressed. Portable payload validation now rejects duplicate saved-page UUIDs before restore mutation. Startup sanitization deterministically keeps the first record for any duplicate UUID already present in legacy local preferences and persists the repaired array. Merge also builds its local lookup without a trapping uniqueness initializer. The focused regression verifies both backup rejection and the legacy first-record reconciliation rule.

### UI-10: Optimize Database can overwrite edits made while it is running

**Severity:** High. **Evidence:** Source race. **Likelihood:** Conditional on overlap with a sufficiently large optimization.

**Location:** Settings/My Data optimization and Study extracted sentences. [RadixStoreDataMaintenance.swift:290](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataMaintenance.swift:290).

**How to reproduce:** Prepare many cleaned-page records needing phrase-link changes. Start Optimize Database. While its detached work runs, edit extracted material or delete one of those pages. Wait for optimization to finish.

**Expected behaviour:** Optimization preserves newer user mutations and cannot resurrect removed artifacts.

**Likely current behaviour:** If optimization changes at least one page, it writes its old full-array snapshot back, potentially discarding edits or restoring deleted cleaned-page records.

**Why it happens:** Records are captured before `await Task.detached`, then the complete result replaces preference state with no revision comparison or per-record merge.

**Recommended fix:** Serialize maintenance with mutations, or apply an ID/revision-checked patch to the current records. Do not replace a mutable store from a stale snapshot.

**Remediation status (2026-09-06):** Addressed. The detached cleaned-page phrase-link pass now commits only when the live records still exactly match its input snapshot. A concurrent edit or deletion aborts before persistence, preserves the newer state, leaves optimization eligible for retry, and reports that the user's changes were kept. The focused regression covers an unchanged snapshot, a concurrent edit and a concurrent deletion.

### UI-11: A startup load error can block the very screens needed to recover

**Severity:** High. **Evidence:** Source. **Likelihood:** Conditional on repository/standard-data load failure.

**Location:** iPad/Catalyst root detail and iPhone startup. [RadixStoreLifecycle.swift:11](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreLifecycle.swift:11), [RootDetailPane.swift:45](/Users/desmondkwang/Developer/Radix/App/RootDetailPane.swift:45), [RootPhoneView.swift:87](/Users/desmondkwang/Developer/Radix/App/RootPhoneView.swift:87).

**How to reproduce:** On a disposable installation, inject a repository-opening failure and relaunch. On iPad/Catalyst try navigating to Settings or My Data; compare compact iPhone behavior.

**Expected behaviour:** A useful load error with Retry, diagnostics, and access to safe export/restore/recovery actions.

**Likely current behaviour:** Regular detail displays Failed to Load before route dispatch, so selecting Settings or My Data cannot reach their recovery UI. Compact phone content does not check the same error and may instead look empty or partially initialized.

**Why it happens:** Error rendering globally replaces detail content; initialization has no user-facing retry/recovery state. The compact shell applies a different policy.

**Recommended fix:** Introduce an explicit startup state and a recovery shell independent of loaded content. Keep Settings, diagnostics and safe recovery accessible on every platform.

### UI-41: Capture bypasses the saved-page deletion impact confirmation

**Severity:** High. **Evidence:** Source. **Likelihood:** Ordinary use; a single mistaken tap can remove a page and its descendants.

**Location:** Capture > saved pages list. [CaptureWorkbenchViews.swift:387](/Users/desmondkwang/Developer/Radix/App/CaptureWorkbenchViews.swift:387), [CaptureTab.swift:225](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:225), [RadixStoreCollections.swift:244](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:244). Compare [FavouritesPresentations.swift:218](/Users/desmondkwang/Developer/Radix/App/FavouritesPresentations.swift:218) and [FilterGridTab.swift:227](/Users/desmondkwang/Developer/Radix/App/FilterGridTab.swift:227).

**How to reproduce:** In a disposable library, create a saved page, a corrected OCR child and a practice pack linked to the original. Open Capture, locate the original in its saved-pages list and tap its trash button once. Repeat with another fixture through Browse or Study for comparison.

**Expected behaviour:** All entry points show the same page name and deletion-impact confirmation, including descendants and linked material, before committing; Cancel leaves everything intact.

**Likely current behaviour:** Capture immediately deletes the original, corrected descendants, source images and linked artifacts handled by the store, then reports Deleted. No confirmation or visible Undo is offered. Browse/Study instead present the impact alert.

**Why it happens:** `SavedImageRow` invokes `onDelete` directly, and Capture's callback calls `deleteCollection` without pending-confirmation state. The store intentionally implements a cascade, so a small row-level trash control has greater impact than its placement suggests. This is separate from UI-12's incomplete cleanup of the remaining references.

**Recommended fix:** Route every saved-page deletion entry point through one pending-deletion/impact-confirmation contract and shared commit path. Add parity tests for Capture, Browse and Study with corrected descendants, cancellation and deleted-current-page state.

**Remediation status (2026-09-06):** Addressed for the Capture parity hole. Capture now stages the selected page, presents the same `deletionImpact` message and destructive/cancel choices as Browse and Study, and calls the shared store deletion only after confirmation. A focused source-level regression guards the request/alert/impact/commit wiring. Full interactive cascade and cancellation coverage remains part of the simulator/device matrix.

## Medium-Priority Findings

### UI-12: Page deletion leaves dangling sentence provenance and descendant practice packs

**Severity:** Medium. **Evidence:** Source. **Likelihood:** High with corrected pages and page-derived study material.

**Location:** Browse/Study > Delete Page and sentence source actions. [RadixStoreCollections.swift:244](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:244), [FavouritesSentenceRows.swift:207](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:207), [FavouritesSentenceRows.swift:271](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:271).

**How to reproduce:** Create a page and corrected descendant, attach a practice pack to the descendant, and save sentences with both deleted-page and surviving-page sources. Delete the original page, then inspect Practice, From Pages and Open Page actions.

**Expected behaviour:** Preserve independent learning memory, remove every deleted page's owned artifacts, and retain navigable links to surviving sources.

**Likely current behaviour:** Descendant pages disappear but their packs can remain; sentence source records still point to deleted pages. A sentence whose first page source was deleted can lose Open Page even when another source survives.

**Why it happens:** Pack deletion tests only the root ID, not the full descendant set. Sentence provenance is not reconciled. Source navigation selects the first page ID rather than the first resolvable source.

**Recommended fix:** Reconcile the full removed-ID set across all stores, distinguish historical provenance from live links, choose surviving sources for navigation, and publish study revisions.

**Remediation status (2026-09-06):** Addressed. The shared page cascade now uses the root plus every corrected descendant when removing page-owned practice packs, phrase extractions, cleaned-page artifacts, images and cached page data. Before mutating page state, it atomically removes those page references from the Sentence Library; source-less non-favorites are deleted, while favorites and records with independent sources remain. Sentence navigation chooses the first source whose page still exists, and the cascade publishes sentence and data revisions. Delete callers surface a storage failure without deleting the page. Focused tests cover descendant/source reconciliation, surviving navigation, favorite retention and full-set practice-link matching. Interactive multi-store fault injection remains open.

### UI-13: An empty extracted-page section in a full restore does not clear current records

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Common when restoring an earlier, smaller library.

**Location:** Wipe and Restore/checkpoints, extracted-page state. [RadixStoreDataImport.swift:218](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataImport.swift:218).

**How to reproduce:** Save a backup with no extracted pages. Later extract sentences from a page. Wipe and Restore the earlier backup, then inspect extracted-page state and reopen Study.

**Expected behaviour:** Complete restore clears data categories that are empty in the selected backup.

**Likely current behaviour:** Old cleaned-page records remain because the importer returns early for empty/missing references or when no pointers resolve.

**Why it happens:** The early guards do not distinguish additive import from complete replacement.

**Recommended fix:** Give absent, empty and invalid fields explicit version-aware semantics. Complete mode must clear an explicitly empty category; unresolved references should produce a report, not silently retain unrelated current data.

**Remediation status (2026-09-06):** Addressed. Extracted-page references are now resolved as preflight work before portable payload mutation. For schema 6, complete restore maps a missing or explicitly empty reference section to an empty replacement, which clears current cleaned-page records and publishes the sentence revision. Schema 1–5 absence remains non-authoritative and preserves current records; additive import still ignores missing or empty input. Empty page definitions or any unresolved sentence pointer now throw a user-facing restore error instead of silently retaining stale pages or applying a partial page. The portable-document restore path retains its rollback behavior if failure occurs after its sentence database has been staged.

### UI-14: Page-specific sentence queries mix unrelated source relationships

**Severity:** Medium. **Evidence:** Probe. **Likelihood:** Plausible once the same sentence appears in several sources.

**Location:** Page-derived sentence lookup/reconciliation. [SentenceLibraryStore.swift:774](/Users/desmondkwang/Developer/Radix/Models/SentenceLibraryStore.swift:774).

**How to reproduce:** Store one sentence with an OCR source on page A and an AI-cleaned source on page B. Query the AI-cleaned sentences for page A, as the page-specific store path does.

**Expected behaviour:** Zero matches: no individual source relationship says AI-cleaned on page A.

**Likely current behaviour:** The probe returns one match, allowing incorrect page-specific results and reconciliation inputs.

**Why it happens:** SQL tests membership in `source_page_ids` independently from the global `has_ai_cleaned_page_source` flag. The predicates can be satisfied by different source entries.

**Recommended fix:** Store/query a normalized source relation or correlated source tuples. Test every combination of page ID and source type across multi-source records.

**Remediation status (2026-09-06):** Addressed without a storage migration. Typed page queries now match the existing serialized `source_type`/`source_page`/`page` tuple emitted for one source entry instead of combining independent page and global-type columns. The in-memory fallback applies the same same-source predicate. Untyped page queries and global source-type queries retain their existing paths. A focused SQLite matrix verifies page A/OCR and page B/AI-cleaned matches plus both crossed non-matches in record and count queries.

### UI-15: Unfavoriting the last row of the last sentence page can strand pagination

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary boundary case.

**Location:** Study > Sentences > Favorites. [FavouritesSentenceData.swift:114](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:114), [FavouritesSentenceRows.swift:252](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:252), [FavouritesTabLifecycle.swift](/Users/desmondkwang/Developer/Radix/App/FavouritesTabLifecycle.swift).

**How to reproduce:** Favorite exactly 11 eligible sentences, use the default 10-row page size with no search, choose Favorites, go to page 2, and remove that row's favorite star.

**Expected behaviour:** Move to page 1 and display its ten remaining rows.

**Likely current behaviour:** The query uses the old second-page offset and returns no rows. The index then clamps to zero without querying again. The screen can show no rows and an invalid range such as `1-0 of 10`, with both page arrows disabled.

**Why it happens:** Count and records are loaded before index correction. The favorite action only refreshes local sentence state; there is no page-index observer that guarantees another query.

**Recommended fix:** Requery whenever clamping changes the offset, preferably returning a valid page/count pair atomically. Cover totals 0, 1, 10, 11 and 20, with deletion, unstar and filter changes.

**Remediation status (2026-09-06):** Addressed. The Sentence Library now has a paged query operation that computes the filtered count, clamps the requested page index and fetches records for that resolved page while holding the same store lock. Its fallback path returns the same coherent page/count/index contract. Study Sentences consumes that result directly, so removing the only row on the last Favorites page immediately displays the preceding page and cannot produce an empty `1-0` range. Focused tests cover totals 0, 1, 10, 11 and 20, the exact 11-to-10 unfavorite transition, boundary deletion and a filter-scope change.

### UI-16: Reopening the phrase notes editor can replace recently saved notes with old text

**Severity:** Medium. **Evidence:** Source. **Likelihood:** High in snapshot-backed phrase sheets.

**Location:** Phrase table > phrase card > Edit Notes. [PhraseInfoHeader.swift:68](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoHeader.swift:68), [PhraseInfoNotes.swift:104](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoNotes.swift:104), [PhraseTableSheet.swift:69](/Users/desmondkwang/Developer/Radix/Views/PhraseTableSheet.swift:69).

**How to reproduce:** Open a phrase inside PhraseTableSheet, edit its notes, Save, and immediately tap Edit Notes again without closing the sheet. Save again or Cancel.

**Expected behaviour:** The second editor opens the just-saved text; Cancel restores that saved value.

**Likely current behaviour:** The editor reloads the original notes. Saving can overwrite the new notes; Cancel can also make the locally displayed notes revert.

**Why it happens:** The card displays `editableNotes` after a successful save but initializes Edit/Cancel from the immutable `phrase.notes`. The parent's selected phrase is a stored value, not a fresh repository lookup.

**Recommended fix:** Maintain one committed local note value or resolve the current phrase by identity. Edit/Cancel should use that committed value, not an older presentation snapshot.

**Remediation status (2026-09-06):** Addressed. Phrase cards now keep the latest successfully saved note as a separate committed local value. Reopening the editor and cancelling an edit both restore that value instead of the immutable phrase snapshot held by the presenting sheet. Failed saves leave the previous committed value intact and keep the editor open.

### UI-17: Quick editors delete or revert immediately, unlike equivalent review screens

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary accidental-tap case.

**Location:** Quick character and phrase editors. [QuickCharacterEditorActions.swift:37](/Users/desmondkwang/Developer/Radix/App/QuickCharacterEditorActions.swift:37), [QuickPhraseEditorView.swift:243](/Users/desmondkwang/Developer/Radix/App/QuickPhraseEditorView.swift:243).

**How to reproduce:** Open an added phrase/character in its quick editor and tap Delete, or open a modified built-in entry and tap Revert.

**Expected behaviour:** A consistent destructive confirmation or a reliable, visible Undo, including a clear account of lost edits.

**Likely current behaviour:** The mutation executes and the editor dismisses immediately. In contrast, the normal phrase card and phrase review use confirmation alerts.

**Why it happens:** Quick-editor management buttons call deletion/revert directly; Revert is also visually styled as an ordinary action although it discards edits.

**Recommended fix:** Share a destructive-action contract across editors/review, with appropriate impact text and undo/recovery behavior.

**Remediation status (2026-09-06):** Addressed. Quick character and phrase editors now use the same pending Delete/Revert contract and require an explicit destructive confirmation before mutating or dismissing. Alert text names the affected item and explains the saved and unsaved edits that will be discarded; character Revert also states that saved notes are retained. Revert controls use destructive styling instead of appearing as ordinary actions.

### UI-18: Failed phrase deletion disappears from the UI and can be reported as removed

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Conditional on database failure.

**Location:** Quick Phrase Editor and Add Phrase review. [RadixStoreDataEdit.swift:371](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataEdit.swift:371), [QuickPhraseEditorView.swift:289](/Users/desmondkwang/Developer/Radix/App/QuickPhraseEditorView.swift:289), [AddPhraseSheet.swift:129](/Users/desmondkwang/Developer/Radix/Views/AddPhraseSheet.swift:129).

**How to reproduce:** Inject a write/lock failure in the added-phrase database, then delete an added phrase through one of these screens. Reopen the list/app.

**Expected behaviour:** Keep the phrase visible and show the deletion error in the active screen.

**Likely current behaviour:** In-memory lists change first; the editor dismisses or the candidate is removed despite failure. The phrase can reappear after reload.

**Why it happens:** `removeDataEditPhrase` returns no result, removes list entries before SQLite deletion, and catches errors into a facade status string the caller does not use as its success condition.

**Recommended fix:** Persist first, return a throwing/typed result, update lists after success, and keep the active editor open on failure.

**Remediation status (2026-09-06):** Addressed. Single-phrase removal now throws and performs the SQLite deletion before publishing any in-memory list or review changes. Quick Phrase Editor dismisses only after success and otherwise remains open with a visible Delete/Revert error. Add Phrase review and extraction keep the candidate visible and replace the success message with the storage error. Other direct callers were updated for the throwing contract without changing their surrounding behavior.

### UI-19: OCR completion can take over navigation after the user has left Capture

**Severity:** Medium. **Evidence:** Source race. **Likelihood:** Plausible with slow recognition or network fallback.

**Location:** Capture > Camera/Album/Files, then global navigation. [CaptureTab.swift:285](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:285), [CaptureTab.swift:316](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:316).

**How to reproduce:** Start recognition on a large image. Before completion, navigate through the global title menu to Study or AI and start another task. Wait for OCR.

**Expected behaviour:** Save the result if that is the stated policy, but preserve the user's newer navigation and offer an Open Page action.

**Likely current behaviour:** Late completion updates the shared capture draft and unconditionally navigates to the newly saved page. There is no explicit cancellation/operation ownership check.

**Why it happens:** Recognition completion and `autoSaveRecognizedImage` do not verify that the same capture operation/context is still active.

**Recommended fix:** Use an operation ID and owned Task; separate durable result delivery from navigation. Only auto-open while the originating capture context remains active.

**Remediation status (2026-09-06):** Addressed. Capture now owns one recognition task, assigns each scan an operation ID and ignores superseded or cancelled completion. Recognized data is assembled locally and a valid page is still saved after the user leaves Capture. Auto-opening Browse additionally requires the same operation, an uninterrupted originating Capture context and the current Capture route; otherwise the newer navigation remains untouched. The saved page remains available through Capture's existing Pages rows, and a retained Capture view also shows an inline saved-page status.

### UI-20: Share-extension imports have no single-consumer ownership or usable failure state

**Severity:** Medium. **Evidence:** Source race/error trace. **Likelihood:** Plausible on launch/foreground handoff and failed OCR.

**Location:** Share to Radix > app activation/import. [RootView.swift:109](/Users/desmondkwang/Developer/Radix/App/RootView.swift:109), [RootView.swift:161](/Users/desmondkwang/Developer/Radix/App/RootView.swift:161), [RadixStoreSharedImageImport.swift:5](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreSharedImageImport.swift:5).

**How to reproduce:** Share an image while Radix is closed, then rapidly activate/reopen it or deliver the import URL while OCR is still running. Separately share unreadable/non-Chinese content and reopen Radix.

**Expected behaviour:** Each shared item imports once, with a visible failed/retry/discard state when it cannot become a page.

**Likely current behaviour:** Multiple Tasks can read the same pending file before removal and create duplicates. OCR errors are silently skipped and retained for later retry; text imports remove their queued input even when no page is created. The user receives no clear outcome.

**Why it happens:** Pending files are enumerated before an await, with no atomic claim/in-flight set. Error handling and acknowledgement differ between image and text imports.

**Recommended fix:** Use an import queue with stable item IDs, atomic claiming, idempotent creation, explicit completion/error states, and a user-visible retry/discard workflow.

**Remediation status (2026-09-06):** Addressed. Root activation and both share URLs now enter one store-owned import task. Incoming text and image files are atomically moved into process-owned directories before any asynchronous work; abandoned claims return to the queue after an app restart. The share file UUID is reused as the saved-page UUID, making replay idempotent. Successful imports are acknowledged, while unreadable, empty, unsupported, or OCR-failed items persist with their error and present Retry, Discard, and Later actions. Text and image imports now follow the same lifecycle.

### UI-21: Valid uncommon Chinese is discarded, and some manual pages cannot be saved without explanation

**Severity:** Medium. **Evidence:** Probe plus source validation trace. **Likelihood:** High for names, historical text and uncommon characters.

**Location:** Text to Page, OCR, shared text and page editing. [CaptureModels.swift:120](/Users/desmondkwang/Developer/Radix/Models/CaptureModels.swift:120), [RadixStoreCollections.swift:106](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:106), [BrowseCollectionSheets.swift:12](/Users/desmondkwang/Developer/Radix/Views/BrowseCollectionSheets.swift:12), [CaptureTab.swift:375](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:375).

**How to reproduce:** Enter `㐀𠮷𰻞你好` into a new page. Also try only extension characters, then a U+4E00-U+9FFF character absent from the bundled dictionary.

**Expected behaviour:** Preserve source text, distinguish valid Chinese from dictionary coverage, and explain unsupported characters before Save.

**Likely current behaviour:** The extractor probe retained only `你` and `好`. Extension-only input cannot enable Save. In-range but unsupported input can enable Save, yet `createCollection` returns nil and the sheet remains without an error.

**Why it happens:** Chinese detection accepts only U+4E00-U+9FFF. The UI's Save test differs from the store's additional dictionary-membership filter.

**Recommended fix:** Centralize Unicode-aware validation, preserve original text even when lookup is unavailable, and return a structured supported/unsupported-character result to the editor.

**Remediation status (2026-09-06):** Addressed. Capture extraction now uses Unicode's ideographic property instead of the Basic CJK block, covering extension characters such as `㐀`, `𠮷`, and `𰻞`. A shared validation result preserves every detected Han character in reading order while separately reporting unique characters with and without Radix dictionary entries. Page creation, OCR correction, editing, startup sanitization, restore and share imports no longer discard valid ideographs solely because dictionary details are unavailable. New-page and edit sheets use that same result to enable Save consistently and explain before saving how many characters will remain without dictionary details.

### UI-22: Album/File/Share image orientation is not propagated consistently to OCR

**Severity:** Medium. **Evidence:** Source risk. **Likelihood:** Conditional on EXIF orientation.

**Location:** Album/Files/shared images versus Camera. [CapturedImage.swift:14](/Users/desmondkwang/Developer/Radix/Services/CapturedImage.swift:14), [CaptureImageIO.swift:38](/Users/desmondkwang/Developer/Radix/Services/CaptureImageIO.swift:38), [CaptureOCRService.swift:34](/Users/desmondkwang/Developer/Radix/Services/CaptureOCRService.swift:34).

**How to reproduce:** Import the same Chinese photo as a physically rotated pixel image and as an EXIF-rotated image through Album and Files; compare Camera and preview orientation.

**Expected behaviour:** All paths recognize the same upright content and reading order.

**Likely current behaviour:** Preview can be upright while Vision receives explicit `.up` for data that requires another orientation, degrading OCR or invoking unnecessary AI fallback. Exact OCR impact needs image-fixture execution.

**Why it happens:** The Data initializer defaults orientation to `.up`; the UIImage initializer maps `imageOrientation`. The loader paths use the former and Vision consumes the separate orientation field.

**Recommended fix:** Read EXIF orientation or normalize pixels once at the input boundary. Test all eight orientations and preserve consistent thumbnail/OCR semantics.

**Remediation status (2026-09-06):** Addressed. `CapturedImage(data:)` now reads `kCGImagePropertyOrientation` from ImageIO metadata when no explicit orientation is supplied, falling back to `.up` only when metadata is absent or invalid. Album, Files and share-extension data therefore pass the same orientation to Vision that UIKit uses for preview display; Camera and Clipboard preserve UIImage orientation semantics through direct mapping or upright normalization when UI-23 downsampling is required. Thumbnail generation continues applying ImageIO's source transform. Generated-image tests cover all eight EXIF orientation values plus missing and invalid data fallbacks, and an integration guard preserves the preview/OCR/thumbnail contract.

### UI-23: Very large images have no pre-decode resource budget

**Severity:** Medium. **Evidence:** Risk; no memory termination was induced. **Likelihood:** Conditional on large scans/panoramas and device memory.

**Location:** Capture Files/Album and Share import. [CaptureImageIO.swift:38](/Users/desmondkwang/Developer/Radix/Services/CaptureImageIO.swift:38), [CapturedImage.swift:14](/Users/desmondkwang/Developer/Radix/Services/CapturedImage.swift:14), [CaptureOCRService.swift:34](/Users/desmondkwang/Developer/Radix/Services/CaptureOCRService.swift:34).

**How to reproduce:** On a disposable small-memory device, import a high-resolution scanned image/panorama while observing memory and responsiveness. Cancel or navigate away during loading.

**Expected behaviour:** Enforce an input budget, downsample for recognition, show progress, and reject impractical images with a retryable explanation.

**Likely current behaviour:** Full file Data and an image representation are loaded before limits; Vision receives original image data. Camera conversion also re-encodes image data. This can cause stalls, memory pressure or app termination at sufficient scale.

**Why it happens:** Thumbnailing limits saved/AI images but does not bound the earlier loading and local OCR pipeline. There is no explicit byte/pixel budget.

**Recommended fix:** Inspect image metadata before decode, cap bytes/pixels, downsample with ImageIO, and make loading cancellable. Measure with real maximum-size fixtures instead of assuming saved thumbnail size bounds peak memory.

**Remediation status (2026-09-06):** Addressed with a shared capture-image resource budget. Album transfers and Files/Share URLs preflight encoded size before reading, and every data-backed image inspects uncached ImageIO metadata before creating a UIKit preview. Inputs above 64 MB or 64 megapixels are rejected with a retryable, size-specific explanation; accepted images above a 3072-pixel edge are downsampled before preview, Vision or AI fallback while retaining explicit EXIF orientation. Camera and Clipboard UIImage inputs use the same pixel gate and produce a bounded upright thumbnail instead of first re-encoding the full image. Picker loading and OCR include cancellation checkpoints. Focused tests cover exact size/pixel/downsampling boundaries and source integration across Album, Files, Share, Camera, Clipboard, Vision and the UI-22 orientation contract.

### UI-24: No-Chinese OCR is treated as an AI setup/failure problem

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary blank, English-only or unreadable photos.

**Location:** Camera/Album/Files OCR. [RadixStoreImageOCR.swift:9](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreImageOCR.swift:9), [GeminiClient.swift:11](/Users/desmondkwang/Developer/Radix/Services/GeminiClient.swift:11), [CaptureTab.swift:285](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:285).

**How to reproduce:** With no Gemini key, scan an image with no Chinese text. With a key configured, repeat and inspect which processing method is used.

**Expected behaviour:** Clearly distinguish no text, unsupported text, local OCR failure and optional cloud retry. Let the user know before an otherwise local-looking capture escalates to cloud processing.

**Likely current behaviour:** Empty/non-Chinese Vision output automatically falls through to Gemini; without a key the user gets Missing Gemini API key rather than a useful no-Chinese result. With a key, the image is sent automatically and the capture message explains the fallback only afterward.

**Why it happens:** A successful empty recognition and a thrown recognition error share one unconditional fallback path. Settings describes automatic Gemini features generally, but Capture has no per-operation method choice or local-only control.

**Recommended fix:** Model recognition outcomes separately, retain the local result/error, and offer an explicit cloud retry or a clearly disclosed persisted opt-in with local-only mode.

**Remediation status (2026-09-06):** Addressed with explicit local OCR outcomes and per-operation cloud consent. Apple Vision now reports Chinese text, no readable text, non-Chinese text and processing failure as distinct results; none automatically invokes Gemini. Capture and Browse retain the selected image, show the specific local outcome, and offer a `Try Gemini` alert that states the image will be sent to Google's Gemini service before any cloud request begins. Declining leaves the local result visible. Shared-image imports remain local-only and surface the specific Vision outcome through their existing Retry/Discard failure flow. Focused coverage verifies all four outcome classes, removal of the unconditional fallback, disclosure on both interactive surfaces and absence of cloud OCR in shared ingestion.

### UI-25: AI template tests can display a previous task's response under a new task

**Severity:** Medium. **Evidence:** Source race. **Likelihood:** Plausible with slow responses and task/source switching.

**Location:** AI > template test panel. [AILinkPromptGeneration.swift:214](/Users/desmondkwang/Developer/Radix/Views/AILinkPromptGeneration.swift:214), [AILinkView.swift:253](/Users/desmondkwang/Developer/Radix/Views/AILinkView.swift:253), [AILinkView.swift:421](/Users/desmondkwang/Developer/Radix/Views/AILinkView.swift:421).

**How to reproduce:** Start a test for task/source A. Switch to B before A completes, and start B's test. Arrange for A to finish last.

**Expected behaviour:** Each result remains associated with its originating task/source; switching cancels or detaches the old result safely.

**Likely current behaviour:** A's response overwrites B's output/status, while resetting the panel permits overlapping requests.

**Why it happens:** Reset clears local flags/output but does not cancel the Task. Completion writes state without comparing the request ID, task or source snapshot.

**Recommended fix:** Own a cancellable request and immutable request context; gate completion by identity and show which task/source produced stored output.

**Remediation status (2026-09-06):** Addressed. The AI template test panel now owns one cancellable Task and active request UUID. Each run captures an immutable task ID, source ID, rendered prompt, task title and source title. Task, source, template or prompt-input changes cancel and clear the active run; success and failure handlers update UI only when both the request UUID and current selection snapshot still match. Starting a second test cancels and supersedes the first, and accepted output is labeled with its originating task and source. Focused policy tests reject stale request, task and source combinations, while a source integration guard verifies cancellation, completion gating and output attribution.

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

### UI-35: Character Notes opens with Save and Cancel outside the visible sheet

**Severity:** Medium. **Evidence:** UI-observed plus source. **Likelihood:** High on SE-size iPhones using the default sheet height.

**Location:** Browse Dictionary > character > Notes. [RootView.swift:68](/Users/desmondkwang/Developer/Radix/App/RootView.swift:68), [QuickCharacterEditorView.swift:66](/Users/desmondkwang/Developer/Radix/App/QuickCharacterEditorView.swift:66), [QuickCharacterEditorForm.swift:5](/Users/desmondkwang/Developer/Radix/App/QuickCharacterEditorForm.swift:5), [QuickCharacterEditorNotes.swift:42](/Users/desmondkwang/Developer/Radix/App/QuickCharacterEditorNotes.swift:42).

**How to reproduce:** At normal text size on an iPhone SE (3rd generation), open Browse Dictionary, select a character such as 危, and tap Notes. Leave the sheet at its initial medium height. Then expand it using the grabber.

**Expected behaviour:** The initial editor visibly identifies itself and exposes Save/Cancel. Expanding should reveal more editing space, not rescue essential commands. Button labels should remain readable.

**Likely current behaviour:** Observed: the medium sheet showed the notes body while its header and Save/Cancel were clipped above the visible sheet. Expanding exposed a header in which Cancel wrapped as `Ca` / `nc` / `el`, alongside an abnormally tall save button. The expanded Cancel action worked.

**Why it happens:** The root presents the editor at medium/large detents. Its initial compact form is non-scrolling and gives the notes editor a 360-point minimum before adding header, padding and dictionary controls. The header is one HStack whose title/subtitle has layout priority over the action buttons; it has no compact arrangement for the remaining width.

**Recommended fix:** Keep Save/Cancel in a stable navigation toolbar or otherwise protected header, make the initial form fit/scroll within its detent, and use a compact header arrangement. Verify both detents at normal text size before extending the Dynamic Type matrix.

**Remediation status (2026-09-07):** Addressed. Character quick editors now open directly at the large detent instead of first presenting a medium layout that cannot contain the editor. Cancel and Save retain their intrinsic horizontal size so the compact header yields title space rather than wrapping either essential action. Phrase quick editors retain their existing medium/large presentation.

### UI-36: Inspecting a phrase removes the result list without a way back to it

**Severity:** Medium. **Evidence:** UI-observed plus source. **Likelihood:** High when comparing several dictionary phrases.

**Location:** Character card > Phrases > Phrase Library > phrase detail. [PhraseTableSheet.swift:65](/Users/desmondkwang/Developer/Radix/Views/PhraseTableSheet.swift:65), [PhraseTableSheet.swift:150](/Users/desmondkwang/Developer/Radix/Views/PhraseTableSheet.swift:150), [PhraseTableSheet.swift:158](/Users/desmondkwang/Developer/Radix/Views/PhraseTableSheet.swift:158), [PhraseTableSheet.swift:236](/Users/desmondkwang/Developer/Radix/Views/PhraseTableSheet.swift:236).

**How to reproduce:** Open 危, tap Phrases, then select 安危 from the 73-match list. Try to return to that list to inspect the next match. Tap the available Back to Character control.

**Expected behaviour:** Phrase inspection has a visible Back to Phrases/results action preserving the list/filter/position, while a separate close/return-to-character action can end the lookup.

**Likely current behaviour:** Observed: the phrase card replaced the entire list and its length controls. The only visible return action was Back to Character, which dismissed the sheet to the character. Comparing another match required opening Phrases again. This is a missing return step, not an incorrectly labeled existing button.

**Why it happens:** `selectedPhrase` switches the body from list to card. The common return button always calls `dismiss()`, and the card's Done also dismisses. The only other reset is tied to phrase-length changes, but that selector is no longer visible in the selected-phrase branch.

**Recommended fix:** Add an explicit in-sheet return that clears `selectedPhrase` and retains result context, or use a normal list/detail NavigationStack within the sheet. Preserve the existing direct return to the originating character as a separate exit.

**Remediation status (2026-09-07):** Addressed. In-sheet phrase detail now presents a distinct `Back to Phrases` action that clears only the selected phrase, alongside the existing return-to-origin action. The result filter and tracked scroll position remain owned by the sheet, allowing successive phrase comparisons without rebuilding the lookup flow.

### UI-37: Text to Page reads the clipboard before the user chooses Paste

**Severity:** Medium. **Evidence:** UI-observed plus source. **Likelihood:** High when the clipboard contains content from another app and iOS requires paste approval.

**Location:** Browse title menu > Text to Page and Capture > Text to Page. [CaptureTab.swift:365](/Users/desmondkwang/Developer/Radix/App/CaptureTab.swift:365).

**How to reproduce:** Copy text in another app, return to Radix, and choose Text to Page intending to type new material. Do not press any Paste command. Test with iOS paste access set to ask.

**Expected behaviour:** Open an empty manual-entry form. Read the clipboard only after an explicit Paste action, or offer a clearly named Paste Text to Page action distinct from manual creation.

**Likely current behaviour:** Observed: iOS asked whether Radix could paste from CoreSimulatorBridge immediately on choosing Text to Page. Declining then opened the form. With allowed access, the current clipboard is automatically used as the draft, potentially surprising a user who wanted to type unrelated text. No clipboard contents were inspected during this test.

**Why it happens:** `beginManualCollection()` assigns `RadixPlatform.pasteboardString` to the draft before presenting the sheet, rather than waiting for a paste gesture.

**Recommended fix:** Initialize the draft empty and provide an explicit system Paste control or standard text-edit paste action. Keep clipboard-image import and manual text entry clearly separate.

**Remediation status (2026-09-07):** Addressed. Both Browse and Capture now initialize Text to Page with an empty draft and do not access the pasteboard while opening the form. Users can still paste deliberately through the standard TextEditor editing controls; clipboard-image import remains a separate explicit action.

### UI-42: Revert All in the backup preview immediately changes the live phrase library

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Conditional on inspecting backup contents with edited base phrases.

**Location:** My Data > backup contents > What is included? > Phrases You Changed. [DataEditMemorySection.swift:31](/Users/desmondkwang/Developer/Radix/App/DataEditMemorySection.swift:31), [DataBackupPreviewSection.swift:162](/Users/desmondkwang/Developer/Radix/App/DataBackupPreviewSection.swift:162), [DataBackupPreviewActions.swift:13](/Users/desmondkwang/Developer/Radix/App/DataBackupPreviewActions.swift:13), [RadixStoreDataEdit.swift:485](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreDataEdit.swift:485), [PhraseEditService.swift:19](/Users/desmondkwang/Developer/Radix/Services/PhraseEditService.swift:19).

**How to reproduce:** Edit the meanings of two built-in phrases, leave their notes empty and save. Open My Data, expand What is included? and Phrases You Changed, then tap Revert All once. Return to those phrases without creating or restoring any backup.

**Expected behaviour:** A destructive batch affecting the live library identifies that scope, previews the exact affected entries/count and asks for confirmation, as bulk phrase review does. It should not resemble an adjustment to an export preview alone.

**Likely current behaviour:** Both live edits are reverted immediately. Only a post-operation count appears. There is a database safety snapshot, but no preflight confirmation or inline Undo/recovery action.

**Why it happens:** The preview's button directly calls `removeAllUnnotedAddedPhrases`. Its predicate scans all added-DB overlays for base phrases without notes, while the visible Phrases You Changed list filters only changed pinyin/meanings via `isBasePhraseCoreEdited`. Thus the action is not even strictly scoped to the displayed rows; status-only or otherwise unchanged overlays can also be removed. Normal review batch actions use explicit alerts.

**Recommended fix:** Move bulk reversion to live-library maintenance, or label and confirm it explicitly in the preview. Compute one immutable affected set for preview, confirmation and commit; preserve the safety snapshot and offer a direct recovery action. Cover notes-protected and non-displayed overlays in tests.

### UI-43: Clear in the translation editor deletes the saved report before Save

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary editing of an existing page explanation.

**Location:** Browse/Study page translation-report editor. [BrowseTranslationReportSheet.swift:38](/Users/desmondkwang/Developer/Radix/Views/BrowseTranslationReportSheet.swift:38), [BrowseImageActions.swift:151](/Users/desmondkwang/Developer/Radix/App/BrowseImageActions.swift:151), [FavouritesStudyGridData.swift:241](/Users/desmondkwang/Developer/Radix/App/FavouritesStudyGridData.swift:241), [RadixStoreCollections.swift:357](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreCollections.swift:357). Compare [PhraseInfoNotes.swift:55](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoNotes.swift:55).

**How to reproduce:** Save a page explanation. Reopen its editor, tap Clear to start replacing the text, then tap Done without Save. Reopen the explanation. Compare with deleting text manually and leaving without Save, or cancelling a Notes draft.

**Expected behaviour:** Clear changes the draft until Save, just like text deletion/Paste. Alternatively, an explicitly named Delete Saved Explanation action confirms immediate removal and provides recovery.

**Likely current behaviour:** The previous explanation is already deleted even though Save was never tapped. Clearing the same text with the keyboard and leaving does not have that persistence effect. Save becomes disabled after Clear, reinforcing uncertainty about whether anything was committed.

**Why it happens:** Both duplicated Clear handlers call `updateCollectionTranslationReport(... report: nil)`, which saves the collection immediately. Typing and Paste only change local drafts. Sharing the sheet has not unified the mutation contract.

**Recommended fix:** Make all editing actions draft-only and commit an empty report deliberately on Save, or separate destructive persisted deletion from draft clearing with an impact confirmation. Test both entry points with Clear/Done, Clear/Paste/Done, manual deletion/Done and Save.

### UI-44: Sentence list stars do not publish the revision used by the open card

**Severity:** Medium. **Evidence:** Risk. **Likelihood:** Conditional on simultaneous list/card presentation on regular-width layouts.

**Location:** Study Sentences row favorite versus sentence sidebar card. [FavouritesSentenceRows.swift:252](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:252), [FavouritesSentenceData.swift:126](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:126), [RadixStoreConversationPractice.swift:422](/Users/desmondkwang/Developer/Radix/ViewModels/RadixStoreConversationPractice.swift:422), [PhraseInfoHeader.swift:85](/Users/desmondkwang/Developer/Radix/Views/PhraseInfoHeader.swift:85), [RootSidebar.swift:318](/Users/desmondkwang/Developer/Radix/App/RootSidebar.swift:318).

**How to reproduce:** On a regular-width iPad/Catalyst layout, keep at least two saved sentences and use the All filter. Open one sentence in the sidebar. Toggle its favorite using the list's star/action menu without reopening the card. Compare the two stars, then toggle using the card and compare again. Avoid relying on removal of the last favorite, which can incidentally change the selected practice topic and invalidate more UI.

**Expected behaviour:** The same favorite operation updates every visible representation in either direction immediately; accessibility labels agree with the stored state.

**Likely current behaviour:** The row updates after its local query refresh while the already-open card can retain the old star/label until another observed-store change causes rendering. Tapping the stale card may perform the opposite action from the one its icon suggests because the action rereads persistence. This is a source-established invalidation gap, not a simulator-reproduced stale star.

**Why it happens:** Row actions write directly to `RadixStudyPreferences` and bump only local `sentenceExampleRevision`. Card actions call `store.toggleFavoriteSentence`, which increments the published `favoriteSentenceRevision`. `FavouritesTabLifecycle` listens to that shared revision, while the sidebar reads favorites through the store rather than observing the preference write. The row path skips that notification contract.

**Recommended fix:** Use a single store mutation for favorites by stable sentence ID, publish the shared revision after successful persistence, and have list/card consumers refresh from it. Test both directions while both views remain mounted; include the analogous list-edit path that currently also bypasses shared mutation publication.

**Remediation status (2026-09-06):** Verified resolved by the current implementation; no production change required. The sentence-row favorite action and sentence editor both increment the published `favoriteSentenceRevision` only after their throwing persistence calls succeed. The mounted Study lifecycle observes that revision and reloads sentence rows, favorite libraries and practice data, while the open sentence card reads its star and accessibility label through the store. Card-originated toggles already use the store mutation that publishes the same revision. Focused source regression coverage now preserves both list-to-card and card-to-list invalidation contracts.

### UI-45: Typing a sentence search silently broadens its source filter to All

**Severity:** Medium. **Evidence:** Source. **Likelihood:** Ordinary use of Favorites/From Pages/From Practice with search.

**Location:** Study Sentences source/search controls. [FavouritesSentenceControls.swift:25](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceControls.swift:25), [FavouritesSentenceData.swift:94](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:94), [FavouritesSentenceRows.swift:145](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceRows.swift:145). Compare [SmartSearchTab.swift:94](/Users/desmondkwang/Developer/Radix/App/SmartSearchTab.swift:94).

**How to reproduce:** Have both favorited and unfavorited sentences containing the same word. Choose Favorites in Study Sentences, then type that word. Re-select Favorites while keeping the query, then append another non-whitespace character. Repeat with From Pages or From Practice. Inspect Delete Results without confirming it.

**Expected behaviour:** Search narrows the selected source, as the minimum-character filter does. Searching all sources should require an explicit scope change, particularly when the resulting set can be bulk deleted.

**Likely current behaviour:** Every meaningful nonempty text change resets the source to All and includes matching records outside the chosen source. The pill updates, but no explicit scope-change action was requested. Delete Results operates on this broadened query; its existing confirmation is a mitigating protection, not a guarantee the user's intended scope was preserved.

**Why it happens:** The search field's `onChange` assigns `sentenceExampleFilter = .all`. The underlying query already accepts source, text and minimum count together. Changing minimum length and running dictionary search do not similarly discard their selected source/script filters.

**Recommended fix:** Preserve the selected source on text edits. Provide an explicit Search All action for expanding an empty result set if needed. Test every source with typing, query refinement, clearing, length changes and the exact bulk-delete target set.

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

### UI-38: The character's component-usage number has no label or discoverable action meaning

**Severity:** Low. **Evidence:** UI-observed plus source. **Likelihood:** High for beginners inspecting their first character.

**Location:** Character information card's large character tile. [CharacterInfoCardHeader.swift:51](/Users/desmondkwang/Developer/Radix/Views/CharacterInfoCardHeader.swift:51), [CharacterInfoCardStyle.swift:16](/Users/desmondkwang/Developer/Radix/Views/CharacterInfoCardStyle.swift:16), [CharacterInfoCardSupport.swift:10](/Users/desmondkwang/Developer/Radix/Views/CharacterInfoCardSupport.swift:10).

**How to reproduce:** Open 危 from Browse Dictionary. Compare the animation header `6 strokes` with the bare `7` under the character tile, then try to infer what tapping that tile will do.

**Expected behaviour:** The number communicates that it counts characters using this component, and the tile communicates that it opens those related characters. It should not resemble a second stroke count, rank or quiz score.

**Likely current behaviour:** Observed: the screen showed `6 strokes` and a bare `7`; the accessibility tree named the button only `危, 7`. Source inspection established that 7 is `usageCount`, not an incorrect stroke value. The meaning and action are not available from the visible label.

**Why it happens:** `usageCountSubtitle` returns only the integer, and `usageCharactersButton` adds no semantic accessibility label/hint. Counts above one open the components popover directly rather than the usage explanation.

**Recommended fix:** Give the quantity and action a compact, explicit meaning, such as a labeled component-usage count, and add an accessibility label/hint describing the related-character action. Do not change valid stroke or usage data to make the numbers agree.

### UI-39: The learning-tier guide becomes a phone sheet with no visible close control

**Severity:** Low. **Evidence:** UI-observed plus source. **Likelihood:** High when a new iPhone user taps a Tier badge.

**Location:** Character information card > Tier 1 (or another Tier badge). [CharacterInfoCardHeader.swift:39](/Users/desmondkwang/Developer/Radix/Views/CharacterInfoCardHeader.swift:39), [CharacterInfoCardGuides.swift:17](/Users/desmondkwang/Developer/Radix/Views/CharacterInfoCardGuides.swift:17), [CharacterInfoCardSupport.swift:34](/Users/desmondkwang/Developer/Radix/Views/CharacterInfoCardSupport.swift:34).

**How to reproduce:** On a compact iPhone, open a character card and tap its Tier badge. Look for a visible Done, Close, back action or grabber before attempting a dismissal gesture.

**Expected behaviour:** Explanatory content remains a clearly dismissible popover, or its adapted sheet supplies an obvious close action consistent with Radix's other reference screens.

**Likely current behaviour:** Observed: a tall sheet containing only guide text appeared, with no visible close button or grabber. Escape dismissed it in the simulator; this is therefore a discoverability problem, not a claim that the application is permanently trapped. Touch/VoiceOver dismissal should still be verified on a device.

**Why it happens:** The Tier button uses a popover that adapts to a sheet in compact width. Its content is only a padded VStack, without a dismissal control, and it does not apply the compact-popover treatment used by some other card explanations.

**Recommended fix:** Specify compact presentation deliberately. Keep a true popover where appropriate, or give the sheet a visible Done/Close action with accessible focus and return behavior.

### UI-40: The empty Text to Page form does not identify its Chinese text field

**Severity:** Low. **Evidence:** UI-observed plus source. **Likelihood:** High for manual entry with an empty or denied clipboard.

**Location:** New Saved Page form. [BrowseCollectionSheets.swift:11](/Users/desmondkwang/Developer/Radix/Views/BrowseCollectionSheets.swift:11).

**How to reproduce:** Choose Text to Page with an empty clipboard or decline paste access, then expand the sheet. Try to determine where the required Chinese content belongs before tapping around.

**Expected behaviour:** The form clearly distinguishes the optional page name from the Chinese text editor, with a field label and an accessible name. Save's requirements should be inferable from the form.

**Likely current behaviour:** Observed: Name was labeled, but the editor appeared as a large blank area inside the same Saved Page section. Only a separate `0 unique Chinese characters detected` footer hinted at its purpose. The UI tool exposed that region as an unnamed Group; this alone is not proof of full VoiceOver behavior.

**Why it happens:** `TextEditor(text: $text)` has a minimum height but no label, placeholder or accessibility label, unlike the existing character-notes editor's explicit empty-state prompt.

**Recommended fix:** Add a Chinese Text field label and accessible name, with a concise empty-editor prompt if needed. Reuse the app's existing labeled-editor pattern without introducing a tutorial or additional navigation.

### UI-46: A filtered-out sentence library is described as having no imported data

**Severity:** Low. **Evidence:** Source. **Likelihood:** Ordinary search or minimum-length filtering.

**Location:** Study Sentences empty state versus Search no-results state. [FavouritesSections.swift:99](/Users/desmondkwang/Developer/Radix/App/FavouritesSections.swift:99), [FavouritesSentenceData.swift:112](/Users/desmondkwang/Developer/Radix/App/FavouritesSentenceData.swift:112), [SmartSearchResults.swift:29](/Users/desmondkwang/Developer/Radix/App/SmartSearchResults.swift:29).

**How to reproduce:** With saved short sentences visible, raise minimum characters above every sentence's length, or enter a query that matches none. Observe the empty message, then lower the minimum/clear the query and see the existing sentences return.

**Expected behaviour:** Distinguish an empty library from no matching sentences. Show the active scope/query and offer a relevant clear/reset action; reserve import instructions for a genuinely empty corpus.

**Likely current behaviour:** Both cases show No Sentences with instructions to import page sentences or practice packs. The user can infer that their existing corpus was lost or not imported successfully, although controls remain available to recover the view.

**Why it happens:** Presentation branches only on filtered `sentenceExampleResultCount == 0`; it does not distinguish corpus emptiness from a query miss. Dictionary Search already uses a query-specific `ContentUnavailableView.search` instead.

**Recommended fix:** Use separate empty-library and no-results states, with a source/search/minimum-filter reset for the latter. Test a nonempty corpus excluded independently by each filter, not just a fresh installation.

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
| Repeated-control parity | Capture/Browse/Study page-delete cancellation and impact; backup-preview reversion scope; translation Clear versus keyboard deletion/Done; simultaneous sentence row/card stars; source plus search combinations; filtered-empty reset; page-local bulk selection versus inspection highlight |

Two particularly important unresolved risks are the regular iPad sidebar's minimum 320-point width before the shell switches to compact, and whether every source-creation entry point applies the same cumulative free-page policy. Both need a policy/device-specific check rather than an invented failure claim. Legacy dated-copy purchase recognition also needs a real historical-entitlement fixture before declaring a regression.

## Fix Order And Maintainability Recommendation

1. **Restore and persistence contract:** UI-01 through UI-07 and UI-09, plus the high-impact unconfirmed page cascade in UI-41. Introduce staged validation, atomic/recoverable mutation, throwing results and honest progress/cancellation. Lock these guarantees down before further sentence-store restructuring.
2. **Identity and concurrency:** UI-08, UI-10 and UI-12 through UI-20, plus UI-44's cross-view favorite invalidation. Centralize mutation/revision publication and reconcile references. Tie asynchronous work to operation and subject identity.
3. **Workflow correctness:** UI-21 through UI-27, UI-30/UI-31 and UI-42/UI-43/UI-45. Unify input validation, image preparation, drafts, destructive batch scope and asynchronous result presentation; preserve filters during search.
4. **First-use interaction:** UI-35 through UI-37. Make editing commands reachable, preserve phrase-result navigation, and make clipboard access intentional.
5. **Accessibility and scale:** UI-28, UI-29 and UI-32, followed by the complete physical-device matrix. Then resolve UI-33/UI-34, UI-38 through UI-40 and UI-46 labeling, dismissal, validation and empty-state inconsistencies.

A wholesale UI rewrite or broad "defrag" is not supported by this evidence. Existing screen/component boundaries are usable. Focused consolidation is warranted around sentence mutations, backup/restore coordination, source-reference cleanup, shared import ownership and AI request lifecycle. Moving methods into smaller files without strengthening those contracts will not fix these bugs.

The repeated-implementation pass adds two specific consolidation targets: a shared saved-page deletion coordinator and one draft/commit contract for page explanations. Extend the existing sentence-store facade so view-local writes cannot skip invalidation. Preserve intentional Browse-versus-Study destinations and already-delegating wrappers. Treat dormant source-picker/import helpers as a separate reachability cleanup after active-path regression tests, not evidence that a major refactor is a prerequisite.

## Verification

- Five focused disposable RadixCore probes executed; results are recorded above.
- Fresh SE simulator launch and the targeted navigation/cancellation/Upgrade flows described above executed.
- `swift test`: passed, 117 tests in 12 suites.
- Catalyst build with `CODE_SIGNING_ALLOWED=NO`: passed; destination-selection warnings only.
- Generic iOS Simulator build: passed.
- Six UI-first additions were observed in the isolated SE simulator, compared against the initial report, and traced to Swift code. Application implementation remained unchanged.
- Six additional source-comparison findings (UI-41 through UI-46) and a 16-row parity matrix were added without application changes. UI-44 remains a runtime-dependent invalidation risk; the other five additions have concrete control-to-store or presentation traces. No new simulator reproduction is claimed for this pass.
- The repeated-implementation pass reran `swift test` (117 tests in 12 suites) and the Catalyst build successfully. The generic iOS Simulator result above is from the earlier pass; it was not rerun for documentation-only changes.
- The UI-01 through UI-07 remediation passed `swift test` with 121 tests in 12 suites. Permanent regressions cover malformed sentence-database restore without live-data loss, write-lock failure without corpus replacement, normalized-key edit collision without record loss, and removal of all practice/artifact owner keys during user-data reset.
- The remediated tree passed an arm64 iOS Simulator build for the disposable SE destination and a Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`. An initial generic universal Simulator build stopped at `lipo` because the build volume had no free space; after deleting only generated Radix Simulator products, the device-specific build passed.
- The UI-09 regression passed in the focused portable-backup suite and in the full `swift test` run (122 tests in 12 suites). The updated import and startup-reconciliation paths compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-41 Capture deletion confirmation regression passed in the focused SwiftUI guardrail suite and in the full `swift test` run (123 tests in 12 suites). The Capture alert wiring compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-10 stale-optimization regression passed in the focused saved-page rules suite and in the full `swift test` run (124 tests in 12 suites). The guarded maintenance path compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-08 saved-page merge regression passed in the focused saved-page rules suite and in the full `swift test` run (125 tests in 12 suites). The content timestamp, preflight and merge paths compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-12 page-deletion reconciliation passed the focused sentence-library and conversation-practice suites and the full `swift test` run (126 tests in 12 suites). The throwing cascade and all deletion entry points compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-13 extracted-page restore regressions passed all 10 focused portable-backup tests and the full `swift test` run (128 tests in 12 suites). The version-aware preflight and empty replacement path compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-14 correlated page/source regression passed all 7 focused sentence-library tests and the full `swift test` run (129 tests in 12 suites). The tuple query and matching fallback compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-15 coherent-pagination regression passed all 8 focused sentence-library tests and the full `swift test` run (130 tests in 12 suites). The paged store query and Study integration compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-16 committed-note regression passed all 6 focused SwiftUI guardrail tests and the full `swift test` run (131 tests in 12 suites). The phrase-card state changes compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-17 quick-editor confirmation regression passed all 7 focused SwiftUI guardrail tests and the full `swift test` run (132 tests in 12 suites). The shared action contract and both editor alerts compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-18 persistence-first phrase deletion regression passed all 8 focused SwiftUI guardrail tests and the full `swift test` run (133 tests in 12 suites). The throwing store API and every direct caller compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- The UI-19 navigation-ownership regressions passed all 8 focused navigation tests, all 9 focused SwiftUI guardrail tests and the full `swift test` run (135 tests in 12 suites). The owned recognition task and Capture completion path compiled in the Mac Catalyst build with `CODE_SIGNING_ALLOWED=NO`.
- All 46 findings contain the seven requested fields; all 188 local file/line references were checked for existence and bounds. The comparison matrix has 16 data rows.
- `git diff --check`: passed for the documentation changes.
- No physical-iPad gate, abrupt-termination restore fault injection, disk-full UI execution, launch/reopen reset check, live-cloud-AI test, real purchase, exhaustive accessibility pass, or large-library UI performance certification was completed.
