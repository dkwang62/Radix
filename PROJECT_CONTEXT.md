# Radix Project Context

This is the current engineering handoff for Radix. It describes the present
product, architecture, durable decisions, risks, and verification expectations.
Update it in the same commit as every coherent work unit. Keep it concise:
Git history is the detailed audit trail.

Read this before work. Read `UI_INTENT.md` before any navigation, layout, or
user-workflow change. `AGENTS.md` contains the repository rules for coding
agents.

Last consolidated: 2026-09-05

## Current State

Radix is a native SwiftUI Chinese-learning workspace for iPhone, iPad, and Mac
Catalyst. It turns captured Chinese into reusable learning material:

```text
Capture -> Browse Page -> Study Sentences -> Phrases -> Characters
```

The product is largely feature-complete. Current work is post-TestFlight
stability, usability polish, output quality, and small maintainability work.
Do not start a broad redesign unless explicitly asked.

Repository branch: `codex/post-testflight-iteration`.

The source project is configured as marketing version `1.0.6`, build `9`.
The latest iPad crash report came from TestFlight `1.0.6 (6)`. Before the next
upload, deliberately set and verify the next build number in both app and share
extension targets; do not assume the repository's current build setting matches
the installed TestFlight build.

The authoritative Xcode project is `Radix.xcodeproj`. Numbered duplicate
projects and the local `Backups/` directory are deliberately excluded from Git
so cross-Mac handoff cannot mistake stale recovery material for current source.

Recovery points:

- `radix-v1.0-before-v1.1` preserves the pre-page/sentence graph product.
- `radix-build-16-before-title-navigation` preserves the title-navigation
  experiment baseline.

## Product Model

The user-facing workspaces have distinct jobs:

| Workspace | Job |
| --- | --- |
| Camera | Capture Chinese from camera, album, files, clipboard, or text. |
| Browse | Inspect the dictionary or the original source page. |
| Study | Review material the user kept: page learning, sentences, phrases, and practice. |
| AI | Set up, test, and apply AI templates. Object-specific AI work starts from that object. |
| My Data | Protect, transfer, restore, and maintain user data. |

The immediate payoff after capture is Browse. All secondary learning layers must
stay linked to their page rather than becoming disconnected parallel features.

### Navigation Rules

- Browse is the source inspector. It owns dictionary inspection, saved-page
  tiles, original/corrected OCR, page editing, and choosing page phrases.
- Study is the learning workspace. It owns page artifacts, sentence review,
  Added Phrases, Conversation Practices, translations, quizzes, and sentence
  storage/transfer.
- A saved page has one shared Browse/Study selection. `Study` from Browse opens
  the relevant Study Page, and `Browse` from Study Page opens that source. This
  explicit pair replaces generic `Back to Browse` or `Back to Study` bars.
- A primary navigation choice clears transient return context. Contextual drill
  flows must always expose one visible, named route back to their origin.
- On iPhone, Browse Dictionary character and phrase cards expose an explicit
  return action named `Back to Browse Dictionary`. Every root title-menu
  navigation choice first clears active
  information cards and deferred launch requests so Browse, Study (including
  Study Pages), AI, Data, or Settings immediately overrides an unfinished
  contextual flow.
- Root titles carry context, for example `Browse - Dictionary`,
  `Browse - [page]`, and `Study - Sentences`; do not repeat the same title in
  page content.
- `Pages` is not a separate primary data model. Browse owns source page
  selection; Study Pages is the page-learning workspace.
- Added Phrases, Conversation Practices, and Sentences are mutually exclusive
  in-place Study sections selected through one `FocusedStudySection` value.
  Do not reintroduce independent boolean section state or a normal
  `Back to Study` control for switching them.

### UI Intent

The user consistently prefers content-first screens, compact controls,
non-duplicated meaning, visible return paths, and user control. Follow
`UI_INTENT.md` as the detailed design contract. In particular:

- do not add explanatory rows, duplicated titles, or broad dashboard controls
  when a compact action or contextual menu already expresses the same thing;
- preserve familiar controls and clear return paths;
- keep destructive actions separated and confirmed;
- on iPad and Mac, preserve useful sidebar behavior rather than reducing the
  experience to an enlarged iPhone layout.

## Application Architecture

`App/RadixApp.swift` creates one `RadixStore` and one `EntitlementManager`.
`RootView` is the global shell: it presents the phone or iPad/Catalyst layout,
owns global sheets/file-transfer presentation, and routes to the active
workspace.

```text
RadixApp
  -> RootView
       -> iPhone navigation shell or iPad/Catalyst split shell
       -> RadixStore facade
            -> ComponentRepository (character dictionary)
            -> PhraseRepository (phrase databases)
            -> RadixStudyPreferences (Study/sentence persistence)
            -> SavedPageImageStore (source-image files)
            -> AI, capture, export, and practice services
```

`RadixStore` is the observable facade for navigation, search, Browse, Study,
Character Studio, and compatibility state. Keep view state adapters with their
state definitions and split store extensions by domain before growing the main
store file. Do not introduce repository protocols unless an alternate concrete
repository is genuinely needed.

The portable `RadixCore` package contains models and rules that do not require
SwiftUI or Apple APIs. Put new cross-platform business rules, persistence
identifiers, parsing, and compatibility behavior there when possible. Keep UI
as orchestration, not a second business-rule implementation.

### Main Ownership Boundaries

- `ComponentRepository` and `ComponentRepositoryQueries` own character
  dictionary loading, search, variants, radicals, and related-character queries.
- `PhraseRepository` owns the authoritative phrase lookup and user-added phrase
  database access.
- `RadixStudyPreferences` is the stable compatibility facade for Study callers;
  do not add new persisted state directly to it. `SentenceLibraryStore` owns the
  SQLite sentence corpus, `ConversationPracticeStore` owns imported packs and
  progress, and `PageStudyArtifactStore` owns phrase extractions and AI-cleaned
  pages. `SentenceLibraryStore` lives in `RadixCore` and receives app-specific
  canonicalization and search policies from the facade, keeping SQLite behavior
  directly testable. Cross-store reconciliation remains in the facade.
- `SavedPageImageStore` owns captured source images in Application Support.
  Saved-page metadata and ordinary page selection must not load or rewrite those
  image bytes.
- `RadixThumbnail` is the shared UIKit/AppKit adapter for rendering encoded
  thumbnail data in SwiftUI; it and the persistence/state helper files remain
  explicit members of the Radix Xcode target.
- `BuiltInPromptTaskID` is the sole built-in AI task identity and capability
  registry. Its persisted `task1`...`task15` raw values must not change.
  `PromptTask` intentionally retains a string ID so custom tasks remain valid.
- `PromptTaskDefaults` and `PromptConfigRendering` own built-in templates,
  legacy-template repair, and placeholder rendering. Menus and result importers
  must use `BuiltInPromptTaskID`, not parallel task-ID constants or literals.
- Conversation Practice is deliberately split into model, validation, library,
  topic, progress, sentence, favorite, capture-import, and quiz-rule files.
- `FavouritesTab` is the Study shell, not the owner of every Study feature's
  transient state. `StudyScreenState` groups Navigation, Sentences,
  Conversation Practice, and Saved Page state and owns multi-field transitions.
  Keep new section state in its matching group and preserve the single root
  `@State` guardrail.
- Shared visual primitives live in `Services/RadixTheme.swift`. Reuse them for
  simple surfaces instead of creating local versions.

## Data Ownership and Recovery

Preserve persisted identifiers, enum raw values, backup fields, and review
statuses. Any change requires an explicit migration and a compatibility test.

| Data | Source of truth | Notes |
| --- | --- | --- |
| Character dictionary | Bundled JSON plus `component_map_changes.json` overlay | The overlay is the tracked editable layer. |
| Main phrases | Bundled `phrases.db` | Read-only in the app and authoritative for bundled phrase meaning/pinyin. |
| Added phrases and notes | `phrases_add.db` | Do not duplicate a phrase already in the main database. Phrase notes remain an overlay here. |
| Saved pages | Preferences-backed `CharacterCollection` metadata plus source-image files | Source images live under Application Support; thumbnails are not retained. Existing embedded images migrate on load. |
| AI-cleaned pages | Preferences-backed `AICleanedPageRecord` artifacts | Page-owned; do not overwrite the source OCR. |
| Sentences | Separate SQLite Sentence Library | Paged/query-based access only; excluded from the JSON payload, but carried by full backup and new checkpoint bundles. |
| Favorites and practice progress | Preferences/portable backup models | They remain learning memory when a linked page is removed. |
| Checkpoints | Local backup bundles | Same-device recovery with sentence and phrase databases. Legacy JSON checkpoints remain readable with an explicit limited-scope warning. |

`UnifiedPackage` is the portable backup contract and retains legacy decoding.
`RadixPreferenceKey` is the canonical stable-key list. `RadixPreferences` is
the Apple storage implementation behind the platform-neutral preference-store
boundary.

Live `CharacterCollection` records are metadata-only. Portable backup and
checkpoint creation reattach each available source image to the collection's
legacy-compatible image field; restore writes it back to `SavedPageImageStore`
and removes the bytes from live preferences. If file storage fails, Radix keeps
one inline source-image copy rather than losing user data.

Backup vocabulary is deliberate:

- `Checkpoint`: a same-device recovery point.
- `Create Backup`: write a new portable backup file.
- `Merge Backup`: combine file and device data, retaining rolling save history.
- `Restore Backup`: replace device data from the file.

Backup restore must validate before mutation and preserve existing data when it
cannot complete. Imports/restores may recommend database optimization, but must
never launch expensive optimization automatically.

Sentence database imports validate integrity, required schema, record decoding,
and stored identity before replacing live data. Sentence mutations throw on
storage failure and key-changing edits reject normalized-key collisions. Full
restore preflights both databases, captures a complete rollback document and
flushes it before writing durable restore intent. Caught failures replay rollback
immediately; startup replays pending rollback after repositories open but before
caches, extracted pages or normal UI load. The intent remains until SQLite,
dictionary, page-image and preference persistence is acknowledged. Recovery is
idempotent and blocks normal data work with a Retry-only screen on failure.
Acquisition and validation can be cancelled; commit and rollback are explicitly
non-cancellable. The recovery policy restores the pre-operation state rather
than finishing an interrupted incoming restore.
Schema-6 complete restore treats a missing or empty extracted-page reference
section as an authoritative empty category. Schema-1 through schema-5 absence
remains unsupported data and does not clear current extracted pages. Every
schema-6 pointer must resolve during preflight or the restore fails before the
portable payload mutates live stores.
Portable payloads reject duplicate saved-page UUIDs before mutation. Startup
reconciliation keeps the first record for a duplicate UUID from legacy local
preferences and persists the repaired collection list.
Saved-page content mutations record `contentModifiedAt`. Additive backup merge
uses it to choose newer content for a matching UUID; older content cannot replace
newer local edits. Differing records without an orderable timestamp fail
preflight before mutation instead of guessing. Viewing dates and backup image
transport fields are not content revisions.
Capture, Browse, and Study must all show the saved-page deletion impact before
calling the shared cascade deletion. Capture stages its pending page and commits
only from the destructive confirmation action. The cascade uses the complete
root-and-corrected-descendant ID set for page-owned artifacts, practice packs,
and sentence provenance. A sentence source link may navigate only to a page that
still exists.

Confirmed page deletion uses `PageDeletionJournal`: an atomically written,
flushed identity record precedes SQLite reconciliation, preference filtering
and acknowledged preference flushes, then throwing image removal. Only after
all steps succeed is the journal retired and UI state published. Startup replays
pending deletion before loading/preprocessing page data; failures show a blocking
Retry screen. Replay is idempotent and preserves favourites, independent sources,
global notes and reusable practice progress. Restore/reset cannot run with pending
intent, and deletion waits for active asynchronous database imports or optimization.
Deletion prepares immutable preference snapshots on a worker with non-blocking
progress, then rechecks import revision, operation availability and persisted
bytes before writing intent. Concurrent edits abort without mutation. Commit has
no suspension points; sentence cleanup scans a narrow source-page index and
decodes only matched rows, including hidden records. Existing databases build
the additive index on first open. Startup recovery remains synchronous.
This provides recovery by finishing a confirmed deletion, not rollback or Undo.
Full-backup restore still has its separate, previously documented crash boundary.

### Page and Sentence Ownership

- Corrected OCR pages, translations, extracted sentence pages, page-created
  practice packs, and page-local notes are page-owned artifacts.
- Favorites, global notes, reusable phrases, and reusable practice progress are
  linked learning memory. Deleting a page must not silently delete them.
- Re-extracting sentences for a page replaces that page's extraction source.
  A sentence is removed only when it has no other source and is not favorited.
- Page-and-source-type sentence queries are relational: the same source entry
  must contain both the requested page ID and source type. Independent matches
  from different sources on one sentence must never satisfy a page-scoped query.
- Sentence pagination returns count, clamped page index, and that page's records
  from one store operation. Mutations or filter changes that remove the current
  last page must display the preceding valid page immediately.
- Sentence Improvement updates Chinese, pinyin, and English together. If the
  sentence belongs to an AI-cleaned page, it must update both the Sentence
  Library and the owning page artifact.
- Simplified Chinese is canonical storage where Radix owns the content.
  Traditional Chinese is display conversion, including legacy/imported data.

### Completed Variant Meaning Migration

On 2026-08-22, a one-time migration enriched 1,171 pure phrase
`variant of ...` meanings and four character definitions while preserving the
variant relationship. It intentionally skipped mixed, unresolved, self, and
chain references. The temporary migration code was removed. Do not rerun it as
a startup or broad maintenance migration. See
`VARIANT_MEANING_MIGRATION_2026-08-22.md` for the audit.

## AI Contract

AI is a shared workflow, not a collection of separate mini-features.

- Object menus expose relevant named AI tasks inside an `AI` submenu. They open
  AI with the object and task already selected.
- The AI workspace owns template editing, template revision, test execution,
  manual copy/open handoff, automatic Gemini execution, and paste/apply.
- Manual handoff copies the full prompt and opens the configured AI app. Do not
  place Chinese page text in a ChatGPT URL query: it corrupts CJK on iPad.
- Automatic Gemini is optional and must always retain the manual fallback.
- `Test AI` runs a template but never applies its output.
- Only custom templates are deletable. Built-in templates normalize legacy
  copies to the current contract.
- `Extract Sentences` creates complete, distinct, coherent sentences from a
  page, expands safe shorthand, filters unrecoverable OCR noise, and returns
  Chinese, pinyin, and English that describe the same final wording.
- `Sentence Improvement` returns and applies that same three-field contract.
- `Structure Phrase for Input` is the source-free exception: it formats pasted
  vocabulary, then feeds the result through the shared Add Phrases importer.
- Page AI tasks use `CollectionPageAITaskKind` and shared page action menus.
  Do not create duplicate task arrays or task-ID capability switches in Browse
  and Study.

## Performance and Stability

Performance and responsive dismissal are product requirements. Treat
full-library work as suspicious unless it is an explicit import, restore,
maintenance operation, or intentional background cache rebuild.

- Never scan all sentences, phrases, pages, or dictionary entries from a SwiftUI
  body, row renderer, card opening, search keystroke, or backup preview.
- Use pagination, indexed queries, batch lookup, cached snapshots with clear
  invalidation, stored phrase hints, and bounded script-conversion caches.
- Do not perform one SQLite lookup per visible row.
- Avoid synchronous heavy work on the main actor, especially during app launch,
  scene transitions, restore, or dismissal.
- `Optimize Database` is the only user-facing maintenance action for costly
  storage work. It needs visible progress and must remain opt-in.
- Detached cleaned-page maintenance may persist only when its live input still
  matches the captured snapshot. Concurrent edits or deletion abort that pass,
  preserve the newer state, and leave optimization available for retry.

### SwiftUI Crash Guardrails

These are evidence-based constraints from real iPad/Catalyst failures. Preserve
them even when a more abstract implementation looks tidier.

- Smart Search's three fixed examples stay explicit in both `ViewThatFits`
  branches. Do not replace them with dynamic `ForEach`.
- Phrase-card animation page chips use a plain horizontal `ScrollView`, never
  `ScrollViewReader`. Animation tiles use explicit rows, not lazy grids.
- Phrase and sentence information cards keep distinct top-level content stacks.
- Added Phrase Review uses fixed platform framing and explicit rows, not
  geometry-feedback-driven adaptive paging or `LazyVGrid`.
- `RootView` must not observe `scenePhase`. The zero-size
  `RadixSceneLifecycleObserver` owns lifecycle callbacks so backgrounding does
  not invalidate the complete navigation/menu graph. It only flushes a truly
  pending Character Studio save and imports shared input on activation.
- The iPad TestFlight `1.0.6 (6)` crash on 2026-08-25 was an iPadOS watchdog
  termination while SwiftUI rebuilt `Menu` during background exit. The lifecycle
  isolation above is the direct mitigation. Test it on physical iPad in the
  next TestFlight build.

Source regression checks live in `SwiftUICrashGuardrailTests`. Extend them when
a production crash reveals a specific unsafe SwiftUI pattern.

Phrase-card note editing keeps the latest successful save as its local committed
value. Reopening or cancelling the editor must restore that value rather than
the possibly stale `PhraseItem` snapshot supplied by a parent sheet.
Quick character and phrase editors stage Delete and Revert actions behind a
shared destructive confirmation contract. Confirmation copy must identify both
saved and unsaved edits that will be discarded; character Revert keeps saved
notes and says so explicitly.
Single-phrase Delete/Revert persists before removing phrase rows from published
UI state and propagates storage errors to the active caller. Editors and review
flows must remain visible with their candidate intact when deletion fails.
Capture image recognition owns a supersedable operation ID and task. Completion
may save its page after Capture loses focus, but it may auto-open Browse only
while the same operation retains an uninterrupted active Capture context.
Share-extension text and image imports use one store-owned consumer. Queue files
are atomically claimed before asynchronous work, reuse their stable UUID for
idempotent page creation, recover abandoned claims on restart, and retain failed
items until the user retries or discards them from the visible failure alert.
Sentence-list favorite and edit mutations must publish
`favoriteSentenceRevision` only after persistence succeeds. Mounted Study lists
observe that revision, and open sentence cards derive their star and accessibility
label from the store so either surface immediately reflects the other.
Saved-page character validity is Unicode-based, not dictionary-based. Capture,
manual creation, editing, OCR correction, share import and restore preserve all
ideographic characters in reading order. Dictionary coverage is a separate
validation result used to explain which characters lack Radix details.
Data-backed capture reads EXIF orientation at the `CapturedImage` boundary.
Album, Files and shared images pass that orientation to Vision while ImageIO
applies the corresponding thumbnail transform; Camera and Clipboard preserve
UIImage orientation semantics through direct mapping or upright normalization.
Capture image inputs are limited to 64 MB encoded and 64 megapixels. Metadata is
read without image caching before preview decode; accepted inputs above a
3072-pixel edge are downsampled before preview and OCR. Album, Files and Share
preflight file-backed transfers, while Camera and Clipboard apply the same pixel
budget to UIImage input. Rejections remain visible and retryable.
Image OCR is local-first. Apple Vision distinguishes Chinese text, no text,
non-Chinese text and processing failure without automatically invoking Gemini.
Capture and Browse require a per-operation disclosure and explicit `Try Gemini`
choice before sending an image to Google; shared-image ingestion stays local-only.
AI template tests own one cancellable request UUID and immutable task/source/prompt
snapshot. Selection or prompt changes cancel the run, and completion may publish
only while both request identity and snapshot still match. Stored test output
shows its originating task and source.

Automated checks cannot prove menu, sheet, rotation, backgrounding, and
dismissal safety on a real device. Every TestFlight candidate must complete a
fresh `TESTFLIGHT_RELEASE_CHECKLIST.md` for its exact version, build, and commit.
Do not carry a physical-device sign-off forward to another build.

## Cross-Platform Behavior

Phone behavior is the cross-platform default unless screen size clearly needs a
different arrangement. iPad and Mac may use the persistent sidebar and richer
information-card space, but must preserve the same terms, selection, return
paths, data behavior, and learning workflow.

- iPad uses the split shell. Mac Catalyst enters its corresponding split shell
  and keeps a visible contextual detail title.
- On iPad/Mac, tapping an added phrase opens it in the sidebar and records it in
  History. A persistent sidebar must never hide the relevant information card.
- On iPhone, compact sentence rows prioritize reading space and wrap long text;
  pinyin and secondary actions move into the card/menu as needed.
- Study sentence, practice, and extracted-page lists share compact deterministic
  toolbar layouts. Avoid measurement-driven multi-candidate interactive layouts
  that can hang or overflow narrow iPad panes.

## Current Workstream

1. Upload the lifecycle-isolation fix in commit `44a0d45` as a new TestFlight
   build after confirming release version/build metadata.
2. Test physical iPad backgrounding, re-opening, rotation, Browse pages, Study
   Sentences, AI menus, and phrase/sentence cards. Collect any new crash log
   before broad changes.
3. Continue only focused usability, correctness, performance, or maintainability
   work. Before adding a feature, search for an existing page, sentence, phrase,
   practice, AI, or info-card flow to extend. Prioritize the read-only findings in
   `RADIX_UI_AUDIT.md`: restore atomicity/cancellation, sentence write failures,
   checkpoint coverage, and identity/reference reconciliation before broad refactors.
   Its repeated-control matrix also identifies page-delete confirmation, editor
   commit semantics, and shared sentence revision publication as focused targets;
   dormant source-picker helpers are not confirmed live UI failures.
4. Schedule a documentation audit after a release or substantial refactor. Do
   not recreate parallel restart/handoff files; update this document instead.

## Required Verification

Page-deletion performance verification (2026-09-08): 21 focused tests passed,
including journal recovery, stale-snapshot rejection and hidden/shared sentence
cleanup across batches, plus existing-database index upgrade. Full `swift test`:
173 tests in 15 suites passed. Signing-disabled Mac Catalyst, both Release probe
builds and `git diff --check` passed. The updated M4, iPhone and iPad probes each
passed seven SIGKILL/relaunch cases and nine timing runs. M4 median commit
times: 3 / 9 / 29 ms for 100 / 1,000 / 5,000 pages (ten sentences per page),
with total preparation plus commit 9 / 66 / 323 ms. The previous wholly
synchronous 5K deletion took 1,207 ms on M4, 1,663 ms on iPhone 13 mini and
2,388 ms on iPad 9th generation. Updated 5K device median commits are 43 ms on
iPhone and 132 ms on iPad (total elapsed 438 / 770 ms). The long pause is reduced,
not eliminated: iPad can still briefly hitch, and first-open index creation and
worst-case bulk cascades are not timed by this warm three-page fixture.
Actual shipping Radix touch/navigation/Retry/frame-pacing checks still need human
sign-off. Reproduction/results are in `Tests/PageDeletionProbe`. Startup deletion
recovery is synchronous.

Full-backup restore rollback verification (2026-09-09): four journal tests and
one startup/UI wiring test passed. The isolated `Tests/RestoreRollbackProbe`
passed five real SIGKILL boundaries while incoming synthetic SQLite/preferences/
images were being replaced and four more while rollback was replaying. Full
`swift test`: 178 tests in 16 suites passed. Signing-disabled Mac Catalyst and
generic iOS builds plus `git diff --check` passed. The probe validates durable journal/replay ordering;
physical-device interruption of the shipping restore flow, disk-full faults and
large-backup timing remain required before release sign-off.

For a normal model/store refactor:

1. `git diff --check`
2. `swift test`
3. `xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build`

The read-only 2026-09-06 UI audit passed these checks (117 tests in 12 suites)
and the generic iOS Simulator build.
Five disposable core probes reproduced failures documented in `RADIX_UI_AUDIT.md`.
A subsequent UI-first SE walkthrough added six distinct findings (UI-35 to UI-40),
including clipped Notes actions, missing phrase-result return, and unsolicited
clipboard access. A repeated-implementation comparison added six source-derived
findings (UI-41 to UI-46) and a 16-row parity matrix, bringing the report to 46
findings. Shared-card favorite invalidation still needs runtime reproduction;
the physical-device/accessibility matrix remains open. No application fixes were
made in these audit passes. The comparison pass reran `swift test` (117 tests),
the Catalyst build, and documentation checks successfully.

The focused UI-01 through UI-07 persistence remediation passed `swift test`
(121 tests in 12 suites), including malformed sentence-database restore,
write-lock preservation, normalized-key collision, and practice/artifact reset
regressions. The arm64 iOS Simulator and Mac Catalyst builds passed with code
signing disabled. A generic universal Simulator build first stopped because the
build volume ran out of space; after removing only generated Radix products,
the device-specific build passed. Physical-device restore interruption,
disk-full UI execution, and launch/reopen reset checks remain open.
The UI-09 saved-page identity fix raised the suite to 122 tests and passed the
Mac Catalyst build. Duplicate page UUIDs are rejected at portable import
boundaries and legacy local duplicates are reconciled during startup.
The UI-41 Capture deletion parity guard raised the suite to 123 tests and passed
the Mac Catalyst build. Capture now requires the same impact confirmation as
Browse and Study before the shared page cascade runs.
The UI-10 stale-optimization guard raised the suite to 124 tests and passed the
Mac Catalyst build. Focused coverage verifies apply, concurrent edit, and
concurrent deletion behavior.
The UI-08 page-merge revision guard raised the suite to 125 tests and passed the
Mac Catalyst build. Focused coverage verifies older/newer selection, transport
equivalence, and ambiguous legacy conflict rejection.
The UI-12 page-deletion reconciliation raised the suite to 126 tests and passed
the Mac Catalyst build. Focused coverage verifies descendant source cleanup,
surviving-source navigation, favorite retention, and descendant practice-pack
matching.
The UI-13 extracted-page restore semantics raised the suite to 128 tests and
passed the Mac Catalyst build. Focused coverage verifies modern empty-category
replacement, legacy absence preservation, additive no-op behavior, and failure
on unresolved sentence pointers.
The UI-14 correlated source-query fix raised the suite to 129 tests and passed
the Mac Catalyst build. Focused coverage verifies every page/type pairing for a
sentence with sources split across two pages.
The UI-15 coherent sentence-pagination fix raised the suite to 130 tests and
passed the Mac Catalyst build. Focused coverage verifies totals 0, 1, 10, 11 and
20 plus unfavorite, deletion and filter-scope boundary changes.
The UI-16 committed-note-state fix raised the suite to 131 tests and passed the
Mac Catalyst build. Focused coverage guards save, reopen and cancel against a
stale parent phrase snapshot.
The UI-17 quick-editor confirmation fix raised the suite to 132 tests and passed
the Mac Catalyst build. Focused coverage guards destructive staging for both
character and phrase Delete/Revert actions.
The UI-18 single-phrase deletion fix raised the suite to 133 tests and passed the
Mac Catalyst build. Focused coverage guards persistence-before-publication and
visible caller errors without advancing or dismissing failed review flows.
The UI-19 capture-operation ownership fix raised the suite to 135 tests and
passed the Mac Catalyst build. Focused coverage verifies that only the current,
uninterrupted Capture operation may auto-open its saved page.
The UI-20 shared-import ownership fix raised the suite to 136 tests and passed
the Mac Catalyst build. Focused coverage guards atomic claiming, one store-owned
consumer, stable page identity, and visible Retry/Discard recovery.
UI-44 was already resolved in production code; its added regression guard raised
the suite to 137 tests and verifies persistence-before-publication plus shared
list/card invalidation. The Mac Catalyst build passed unchanged production code.
The UI-21 Unicode saved-page fix raised the suite to 140 tests and passed the Mac
Catalyst build. Focused coverage verifies CJK extension extraction, dictionary
coverage reporting, and persistence independent of dictionary membership.
The UI-22 EXIF-orientation fix raised the suite to 142 tests in 14 suites and
passed the Mac Catalyst build. Generated fixtures cover all eight EXIF values,
with source coverage guarding consistent preview, Vision and thumbnail use.
The UI-23 capture-image budget raised the suite to 144 tests in 14 suites and
passed the Mac Catalyst build. Focused coverage verifies byte, pixel and
downsampling boundaries plus Album, Files, Share, Camera, Clipboard, Vision and
orientation integration.
The UI-24 local-first OCR fix raised the suite to 146 tests in 14 suites and
passed the Mac Catalyst build. Focused coverage verifies all local outcomes,
explicit cloud disclosure on Capture and Browse, and local-only shared imports.
The UI-25 prompt-test ownership fix raised the suite to 148 tests in 14 suites
and passed the Mac Catalyst build. Focused coverage verifies request, task and
source mismatch rejection plus cancellable UI ownership and output attribution.
UI-35 through UI-37 keep character-editor actions visible on compact phones,
preserve phrase-result navigation during detail inspection, and prevent Text to
Page from reading the clipboard before an explicit paste action. Three focused
guards raised the suite to 153 tests, and the Mac Catalyst build passed.
UI-11, UI-27, UI-31, UI-42 and UI-43 now preserve startup recovery access,
sentence-AI request identity, one-score-per-quiz-item behavior, confirmed
display-scoped phrase reversion and draft-only translation clearing. Five
focused guards raised the suite to 158 tests in 14 suites; the Mac Catalyst
build passed with signing disabled.
UI-45 and UI-46 preserve sentence source scope while searching and distinguish
an empty sentence library from a filtered no-match result with an explicit
filter reset. One focused guard raised the suite to 159 tests in 14 suites; the
Mac Catalyst build passed with signing disabled.
UI-26 now requires an explicit Save, Discard or Cancel decision before an
unsaved main-editor AI template draft can be left through task selection,
task creation or All Templates. One focused guard raised the suite to 160 tests
in 14 suites; the Mac Catalyst build passed with signing disabled.
UI-28 gives the identified phrase, sentence, Examples and classification
surfaces semantic Dynamic Type, reflow at accessibility sizes and 44-point touch
targets without globally changing legacy caption typography. Its focused guard
and all 180 tests in 16 suites passed; Catalyst, generic iOS and SE-simulator
builds passed, and Accessibility XXXL launch was checked on the SE simulator.
Human VoiceOver focus/activation and physical-device layout remain release gates.
UI-29 keeps phrase-classification controls and page navigation fixed while the
tile grid scrolls within its remaining height. One focused guard raised the
suite to 161 tests in 14 suites; the Mac Catalyst build passed with signing
disabled. Compact-device and largest-Dynamic-Type interaction remain open.
UI-32 moves character/phrase example lookup off sheet presentation, pages exact
matches progressively, refreshes on sentence mutations, and provides explicit
loading and empty states. Its focused guard and all 179 tests in 16 suites
passed; the signing-disabled Mac Catalyst build passed. The isolated release
probe then passed 12 cold-process physical-iPhone runs at 10,000 and 50,000
sentences. Worst-device median first-page time at 50,000 common-character
matches was 66.7 ms with a normal 16.7 ms maximum display interval. Results and
reproduction steps are in `Tests/SentenceExamplesPerformanceProbe`.
UI-34 standardizes the affected user-facing vocabulary: `My Data` is the
primary destination, editors operate on a `Saved Page`, `Checkpoint` means a
complete same-device learning state, `Backup` means a portable file, and
`Safety Copy` means per-database maintenance recovery. One focused guard and all
181 tests in 16 suites passed; the signing-disabled Mac Catalyst build passed.
UI-30 gives Upgrade an in-session StoreKit recovery contract: empty product
loads retry on presentation and by explicit action; purchase and restore expose
pending, cancelled, no-purchase, failure and busy outcomes; and manager plus UI
guards prevent overlapping operations. One focused guard and all 182 tests in
16 suites passed; the signing-disabled Mac Catalyst build passed. Ask to Buy,
subscription lapse and delayed transaction timing remain StoreKit/device gates.

For release work or platform-sensitive UI/data changes, also run:

```sh
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'generic/platform=iOS Simulator' build
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Before describing a TestFlight candidate as release-ready, complete and record
the build-specific physical-iPad gate in `TESTFLIGHT_RELEASE_CHECKLIST.md`.
Codex can verify compilation but cannot substitute for that device sign-off.

Simulator launch failures caused by CoreSimulatorService are environmental;
report them separately from compilation failures. For a screen with prior crash
history, also exercise that workflow on iPhone, iPad, and Catalyst before
release.

## Documentation Map

- `PROJECT_CONTEXT.md`: current architecture, ownership, workstream, and checks.
- `UI_INTENT.md`: durable UI and product decisions.
- `RADIX_UI_AUDIT.md`: prioritized 2026-09-06 hostile QA findings, reproduced
  disposable persistence probes, source traces, and remaining device-test matrix.
- `AGENTS.md`: instructions for coding agents.
- `TESTFLIGHT_RELEASE_CHECKLIST.md`: mandatory build-specific automated and
  physical-iPad release gate.
- `PORTABLE_BACKUP_FORMAT.md`: portable backup format contract.
- `VARIANT_MEANING_MIGRATION_2026-08-22.md`: completed one-time dictionary audit.
- `APP_STORE_COPY.md` and `THIRD_PARTY_LICENSES.md`: publication material.

When this file is updated, replace outdated statements rather than appending a
session diary. Keep the current workstream to a small actionable list.
