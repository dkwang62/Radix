# Radix Project Context

This is the current engineering handoff for Radix. It describes the present
product, architecture, durable decisions, risks, and verification expectations.
Update it in the same commit as every coherent work unit. Keep it concise:
Git history is the detailed audit trail.

Read this before work. Read `UI_INTENT.md` before any navigation, layout, or
user-workflow change. `AGENTS.md` contains the repository rules for coding
agents.

Last consolidated: 2026-09-09

## Current State

Radix is a native SwiftUI Chinese-learning workspace for iPhone, iPad, and Mac
Catalyst. It turns captured Chinese into reusable learning material:

```text
Capture -> Browse Page -> Study Sentences -> Phrases -> Characters
```

The product is largely feature-complete. Current work is post-TestFlight
stability, usability polish, output quality, and small maintainability work.
Do not start a broad redesign unless explicitly asked.

Character stroke animations expose a shared `Read Aloud` control in compact
and regular character previews, lightweight character previews, and phrase
character tiles. The control uses the existing speech preference and character
speech service; tapping the animation itself retains its existing inspection
behavior.

Repository branch: `codex/post-testflight-iteration`. The source project and
current source version is `1.1` build `60` (not yet distributed). Every committed application
change must increment `CURRENT_PROJECT_VERSION` in `project.yml`, regenerate
the Xcode project, and preserve app/extension build parity.

`project.yml` is also the signing source of truth for both targets. Keep
automatic signing on Apple Team `7PSNWRPJ5B` (Leong Wen Kwang) so regenerating
the Xcode project does not clear the selected team.

Physical iPad build `1.1 (30)` produced three background scene-update watchdog
terminations on 2026-09-21 while iPadOS was laying out the SwiftUI hierarchy for
its system snapshot. Mobile Radix now substitutes a plain background snapshot
surface as soon as the scene becomes inactive and restores the live hierarchy
when active. Keep this transition lightweight and do not add app content to the
snapshot surface.

The authoritative Xcode project is `Radix.xcodeproj`. Numbered duplicate
projects and the local `Backups/` directory are deliberately excluded from Git
so cross-Mac handoff cannot mistake stale recovery material for current source.
Keep the repository limited to application/Xcode inputs, tests, release assets,
and Codex operating material. Generated `.build` state remains ignored and may
be recreated; completed one-off utilities and unrelated machine files belong in
an external archive. `Scripts/` contains only active release or asset tooling.
The Advanced Pro source ZIP excludes itself, its generated manifest, build
products, and machine-local state so every archived project file can match the
committed source tree exactly.

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

- Browse and Study page Actions are rendered from one canonical ordered
  `CollectionPageAction` list. Each workspace supplies route handlers; the list,
  labels, and ordering must not be duplicated or allowed to drift. Both expose
  Rename, Edit, Choose Page Phrases, Original OCR when applicable, Explanation,
  and Delete; Study reuses the same editor sheets rather than routing through Browse.

- Browse is the source inspector. It owns dictionary inspection, saved-page
  tiles, original/corrected OCR, page editing, and choosing page phrases.
- Study is the learning workspace. It owns page artifacts, sentence review,
  Added Phrases, Conversation Practices, translations, quizzes, and sentence
  storage/transfer.
- A saved page has one shared Browse/Study selection. `Study` from Browse opens
  the relevant Study Page, and `Browse` from Study Page opens that source. Both
  surfaces use a shared compact layout: the page name is the selection menu and
  second-row Actions precede the Browse/Study segmented control. This replaces generic
  back bars and duplicate page pickers. Study's page sort belongs inside the page-name menu, not
  in a detached header pill. The selected Study Page workspace stays expanded,
  uses scan date rather than last-viewed context, and shows artifacts only as
  actionable chips rather than duplicate header indicators.
- Study keeps `Pages`, `Sentences`, and `Conversation` visible in one compact
  local navigation row; `More` contains Recent, Favorites, Added Phrases, and
  Checkpoints. The row remains one line on narrow iPhones.
- Every screen title opens the same bounded, single-level navigation map:
  Create Page sources, Browse destinations, every Study section, one direct AI
  destination, My Data sections, Settings, and contextual Help. Search and
  Camera remain the always-visible buttons; record lists and AI task lists do
  not expand the title menu.
- Browse page Actions includes a dedicated Rename Page sheet. Renaming changes
  only the page's display name; its stable ID, source text, sentences, and linked
  study artifacts remain unchanged. Edit Page remains available for source-text
  changes.
- A primary navigation choice clears transient return context. Contextual drill
  flows must always expose one visible, named route back to their origin.
- On iPhone, Browse Dictionary character and phrase cards expose an explicit
  return action named `Back to Browse Dictionary`. Every root title-menu
  navigation choice first clears active
  information cards and deferred launch requests so Browse, Study (including
  Study Pages), AI, My Data, or Settings immediately overrides an unfinished
  contextual flow.
- Phrase-card character taps open a character card. A caller may provide a
  different in-flow character destination for its own navigation context.
- Phrase animation tiles expose distinct compact controls for read aloud and
  opening the character card; do not rely solely on tapping the web animation.
- Phrase-to-character inspection preserves an explicit return path to the
  originating phrase. Place animation actions in the header and use numeral-only
  stroke labels on both Phrase and Character cards. On compact iPad sidebars,
  keep the numeral at the header's leading edge and actions trailing; capture
  the phrase return context in the button action so sheet cleanup cannot turn
  a visible return control into a no-op.
- Root titles carry stable workspace context, for example `Browse - Dictionary`,
  `Browse - Pages`, and `Study - Sentences`. A selected saved page's name and scan
  date belong in the shared Browse/Study page header, not in the root title.
- In Study Recent, keep the script toggle and `Clear Recent` in one trailing
  control row. Favorites retains only the script toggle; Pages retains neither.
- Saved-page headers use the page name itself as the selection menu and show a
  label-free `dd MMM yy` date matching the active Viewed/Scanned sort order.
  Keep compact icon-only Actions and the Simplified/Traditional toggle in the
  second control row for both Browse and Study; Browse also keeps compact read
  aloud, a compact 11-point Browse/Study segmented control, and compact 11-point
  `All | Unique` there. The page-name menu owns the cross-platform
  Viewed/Scanned sort choice.
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
  registry. Its persisted `task1`...`task16` raw values must not change.
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
- Primary Browse/Study switching avoids incidental persistence work. Browse
  preserves a valid selected page instead of rewriting page metadata on every
  entry. Switching the already-selected saved page between Browse and Study is
  persistence-free and does not change its viewed date. Study Pages bypasses
  Conversation Practice initialization, builds one page-artifact snapshot, and
  reuses decoded practice/page payloads until their stored data changes. Other
  Study sections load shared practice/favorite references in one pass, run the
  legacy phrase-favorite conversion once per relevant data change, and consume
  the root's cached checkpoint list instead of rescanning checkpoint files.
- Interactive navigation publishes grouped state transitions. Browse chooses
  its final sort mode once, computes dictionary-grid filtering and ordering from
  an immutable snapshot off the main actor, and publishes one completed result.
- Sentence-example availability and AI sentence-picker searches run outside
  SwiftUI rendering. AI sentence search is lazy and debounced. Stroke-order
  previews run three finite passes instead of permanent background loops; a
  changed or dismissed preview cancels its remaining passes.
- Search history and high-traffic phrase, page, lineage, practice, and editor
  caches are bounded. Backup previews cap repeated phrase tiles while retaining
  the full restore payload.
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
| AI-cleaned pages | Preferences-backed `AICleanedPageRecord` artifacts | Page-owned; do not overwrite the source OCR. Deleting a page's Extracted Sentences result removes only that page artifact and its `.aiCleanedPage` sentence sources; independent or favorited sentences remain under the existing sentence-retention rules. |
| Sentences | Separate SQLite Sentence Library | Paged/query-based access only; excluded from the JSON payload, but carried by full backup and new checkpoint bundles. Every sentence must be tied to a saved page source or a conversation/practice source; favorites alone are not a retention root. Untethered sentence rows are rejected on write and pruned during startup/import cleanup. |
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
- `Merge Backup`: combine file and device data and update the user-selected
  backup. Document-provider/iCloud merges must not move sibling files for
  rolling history because the picker grants access to the chosen file, not its
  containing folder.
- `Restore Backup`: replace device data from the file.

Backup restore must validate before mutation and preserve existing data when it
cannot complete. Imports/restores may recommend database optimization, but must
never launch expensive optimization automatically.

Sentence database imports validate integrity, required schema, record decoding,
and stored identity before replacing live data. Sentence mutations throw on
storage failure and key-changing edits reject normalized-key collisions.
Distribution complete restore uses `RestoreGenerationStore`: production
preferences, sentence and added-phrase databases, page images and dictionary
overlay live under one active generation. Restore preflights the incoming
document, clones the active generation with filesystem copy-on-write where
available, applies and validates the replacement in staging, then atomically
publishes one durable generation decision. Startup rolls an interrupted staging
generation back or finishes a promoted generation before repositories and UI
state open. The previous generation remains available until the replacement
reopens successfully, and retirement cleanup runs off the UI path. Recovery is
idempotent and blocks normal data work with a Retry-only screen on failure.
Complete restore writes each embedded SQLite database directly into the staged
generation and validates it there. It does not first materialize validation and
restore copies or invoke SQLite's live-database rollback copy; one full staged
validation precedes promotion and the reopened generation receives a lightweight
schema/open check.
The Restore Backup confirmation does not create a separate checkpoint bundle:
the retained previous generation is the recovery copy until the staged library
reopens, avoiding a second full export before restore begins. User-created and
scheduled checkpoints remain unchanged.
Preference mutations made during a complete staged restore are batched in memory
and durably written once before validation and promotion. A pre-flush interruption
still rolls back to the previous generation; promotion never publishes an
unflushed preference set.
Conversation-practice restore canonicalizes all imported packs in one sentence
transaction and resolves references in bounded batches. Phrase presence is also
queried in batches rather than once per practice entry; this preserves the same
sentence sources and fallback phrase cache without corpus-sized repeated work.
Legacy pending rollback documents remain readable. Additive restore and the
source-checkout live-data development path retain the existing rollback journal;
neither changes the portable backup format or page-deletion journal.
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
Bundled standard data is stripped of saved pages and page selection before its
one-time additive import. Only a user-selected portable backup may transfer
saved pages, so legacy bundled authoring pages cannot block startup with a merge
conflict. The current standard-data import marker is
`radix_unified_backup.1.1.13`.
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
Full-backup restore uses its separate rollback journal and is not covered by the
page-deletion journal.

### Page and Sentence Ownership

- Sentence Chinese and extraction Chinese text/phrase hints use Simplified at
  import. Backup/checkpoint reference generation also simplifies legacy extraction
  copies before looking up SQLite keys; Traditional text must not silently omit
  extraction references. Preserve page/sentence IDs, titles, pinyin and English.
- User-added phrases and page phrase extractions also persist Simplified Chinese.
  Opening, importing, restoring, or replacing an added-phrase database merges
  legacy Traditional/Simplified duplicates under the Simplified word, retaining
  combined notes and the most recently active review state. Preserve original
  OCR, titles, notes, and display conversion as user-facing source text.

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
a startup or broad maintenance migration. Git history retains the detailed
migration audit and checksums.

## AI Contract

AI is a shared workflow, not a collection of separate mini-features.

- Object menus expose relevant named AI tasks inside an `AI` submenu. They open
  AI with the object and task already selected.
- Sentence cards expose one shared Explain/Improve AI menu from the card and
  directly from Chinese or English text. Those text views do not enable native
  selection because it consumes Mac right-clicks; the shared menu preserves
  explicit Copy Chinese and Copy English actions. Main-panel sentence rows use
  that same component before any row-specific Favorite/Edit/Delete actions;
  automatic failures are shown in Study rather than discarded.
- The AI workspace owns template editing, template revision, test execution,
  manual copy/open handoff, automatic AI execution, and paste/apply.
- Manual handoff copies the full prompt and opens the configured AI app. Do not
  place Chinese page text in a ChatGPT URL query: it corrupts CJK on iPad.
- Automatic AI is optional and must always retain the manual fallback. Gemini
  remains the default direct backend; FreeLLMAPI may run automatic tasks through
  its OpenAI-compatible `/v1/chat/completions` endpoint using
  the saved FreeLLMAPI URL/key and model `auto`. The Settings screen includes a
  `Use Local FreeLLMAPI` action that saves the local endpoint/key together;
  selecting FreeLLMAPI also backfills the local URL/key when either
  saved value is blank.
- `Test AI` runs a template but never applies its output.
- Only custom templates are deletable. Built-in templates normalize legacy
  copies to the current contract.
- `Extract Sentences` creates complete, distinct, coherent sentences from a
  page, expands safe shorthand, filters unrecoverable OCR noise, and returns
  Chinese, pinyin, and English that describe the same final wording. The
  generated sentence contract is note-free and phrase-hint-free; old note-like
  or `phrase_hints` fields may remain parseable for compatibility, but built-in
  sentence-extraction templates must not request or emit them.
- `Sentence Improvement` returns and applies that same three-field contract.
- `Structure Phrase for Input` is the source-free exception: it formats pasted
  vocabulary, then feeds the result through the shared Add Phrases importer.
- **Browse → Image from Transcripts** opens the shared free-text AI workspace
  with **Extract Sentences from Transcript** (`task16`). Paste a transcript once;
  Run Automatically executes the same editable prompt used by manual handoff and
  saves the bilingual sentence array without a second paste. Failure retains the
  source and offers the existing copy/open/paste/apply flow. Test AI remains
  non-mutating. Source/task/prompt changes or leaving the workspace cancel an
  in-flight request so stale answers cannot be applied.
- Transcript imports require complete Chinese, pinyin, and English per entry.
  The importer accepts fenced/prose-wrapped JSON, trailing commas, a single
  object or comma-separated object list, and `sentences`/`entries` wrappers.
  Existing field aliases are supported and missing/duplicate IDs are repaired.
  Legacy phrase hints are still tolerated and filtered, but current built-in AI
  templates no longer request them. Sentence wording is never changed by format
  repair; incomplete entries still reject the batch. Provider errors and incomplete
  bilingual answers are rejected before creating a page. Valid results reuse
  the saved-page sentence store and indexing; the original transcript is kept in
  the manual page's source text. Manual answer import validates the answer
  first and uses its Chinese as page source if Source Text is empty/non-Chinese;
  users do not need to paste the source again after a restart. Reapplying the
  same transcript updates its list.
  New transcript pages use the existing free-page allowance. Open in Study uses
  the ordinary page learning workspace.
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
- `RootView` must not read `scenePhase` directly. The zero-size
  `RadixSceneLifecycleObserver` owns lifecycle callbacks. On mobile, inactive
  state replaces the complete navigation/menu hierarchy with the plain
  `backgroundSnapshotBody` before iPadOS captures its system snapshot;
  background state flushes only a truly pending Character Studio save. The
  background-to-inactive foreground transition restores the hierarchy early so
  it can render behind iPadOS's return animation; active state imports shared
  input. Do not render normal app content behind the background snapshot
  surface while the app is leaving the foreground.
- Background scene-update watchdog terminations were reproduced on physical
  iPad in builds `1.0.6 (6)`, `1.0.6 (9)`, `1.1 (9)`, and three times in
  `1.1 (30)`. Build 30 stacks were all inside SwiftUI display-list, color, or
  text layout while iPadOS captured a background snapshot. Physical-iPad
  background/foreground repetition remains a release gate for the replacement
  snapshot hierarchy.

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
- Shared sentence rows do not display ordinal/rank badges; row space belongs to
  the sentence text and trailing actions. Keep rank data for sorting and practice
  logic only unless a future design gives it a dedicated non-crowding location.
- Study sentence, practice, and extracted-page lists share compact deterministic
  toolbar layouts. Avoid measurement-driven multi-candidate interactive layouts
  that can hang or overflow narrow iPad panes.

## Current Workstream

The 2026-09-06 hostile UI audit's 46 findings have focused remediations and
regression coverage. The completed narrative audit was removed after its durable
contracts were folded into this document and the tests. Do not reopen an item
without a new reproduction or evidence that a documented contract has regressed.

1. Complete the exact-build physical-iPad gate in
   `TESTFLIGHT_RELEASE_CHECKLIST.md`, including background/foreground, rotation,
   navigation, menus, cards, and restore/recovery access.
2. Complete remaining physical accessibility checks: VoiceOver focus,
   activation and focus return; largest Dynamic Type on compact and split
   layouts; and keyboard/safe-area behavior.
3. Exercise StoreKit Ask to Buy, delayed transactions, restore with no purchase,
   and subscription lapse in Apple's test environment.
4. Fault-test complete restore for disk exhaustion and interrupt the shipping
   app on a disposable physical-device library. Record large-backup timing.
5. Confirm the cumulative free-page policy at 99/100/101 pages across Camera,
   Text, Clipboard, Files, Album, and Share entry points. Decide explicitly
   whether Share is exempt before changing enforcement.
6. Check the regular iPad sidebar near its 320-point minimum, including Stage
   Manager transitions to compact width.
7. Continue only focused correctness, usability, performance, or maintainability
   work. Keep this file current and use Git history for completed work details.

## Required Verification

Latest application baseline (2026-09-22): `swift test` passed 222 tests in 19
suites. Signing-disabled Mac Catalyst and generic iOS Simulator builds target
source build 60. Browse/Study switching no longer repeats checkpoint scans,
legacy phrase-favorite scans, saved-page persistence, or duplicate grid
recomputes on ordinary tab entry. Study Pages also avoids unrelated conversation
initialization and repeated JSON decoding. Dictionary grid work runs off the main
actor and high-traffic caches are bounded; real-library device timing remains a
human verification step. Live provider
execution and physical-device UI acceptance for the transcript task remain
unverified. Per-change verification details belong in Git history, not in this
handoff.

Specialized validation:

- Page deletion: the Mac, iPhone 13 mini, and iPad 9th-generation probe passed
  all seven SIGKILL/relaunch boundaries. At 5,000 pages and 50,000 sentences,
  median synchronous commit was 29/43/132 ms respectively. See
  `Tests/PageDeletionProbe/RESULTS.md`. Human shipping-UI checks, first-open
  index timing, and worst-case bulk cascades remain open.
- Full restore: generation integration tests verify old/new consistency across
  preferences, both databases and page-image paths before and after durable
  promotion. The legacy `Tests/RestoreRollbackProbe` remains the compatibility
  probe. Physical-device interruption, disk exhaustion and large-backup timing
  for the shipping build remain open.
- Sentence examples: the physical-iPhone release probe passed 12 cold-process
  runs at 10,000 and 50,000 sentences without a query-caused main-thread stall.
  See `Tests/SentenceExamplesPerformanceProbe/RESULTS.md`.

For a normal model or store change, run:

```sh
git diff --check
swift test
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix \
  -destination 'platform=macOS,variant=Mac Catalyst' \
  CODE_SIGNING_ALLOWED=NO build
```

For release work or platform-sensitive UI/data changes, also run:

```sh
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix \
  -destination 'generic/platform=iOS Simulator' build
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix \
  -destination 'generic/platform=iOS' CODE_SIGNING_ALLOWED=NO build
```

Before describing a TestFlight candidate as release-ready, complete and record
the build-specific physical-iPad gate in `TESTFLIGHT_RELEASE_CHECKLIST.md`.
Automated compilation does not substitute for that device sign-off.
CoreSimulatorService launch failures are environmental and should be reported
separately from compilation failures.

## Documentation Map

- `PROJECT_CONTEXT.md`: current architecture, ownership, workstream, and checks.
- `UI_INTENT.md`: durable UI and product decisions.
- `AGENTS.md`: instructions for coding agents.
- `TESTFLIGHT_RELEASE_CHECKLIST.md`: mandatory build-specific automated and
  physical-iPad release gate.
- `PORTABLE_BACKUP_FORMAT.md`: portable backup format contract.
- `APP_STORE_COPY.md` and `THIRD_PARTY_LICENSES.md`: publication material.
- `Tests/*Probe/README.md` and `RESULTS.md`: reproducible specialized validation
  instructions and measured baselines.

When this file is updated, replace outdated statements rather than appending a
session diary. Keep the current workstream to a small actionable list.
