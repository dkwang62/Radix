# Radix Project Context

This is the current engineering handoff for Radix. It describes the present
product, architecture, durable decisions, risks, and verification expectations.
Update it in the same commit as every coherent work unit. Keep it concise:
Git history is the detailed audit trail.

Read this before work. Read `UI_INTENT.md` before any navigation, layout, or
user-workflow change. `AGENTS.md` contains the repository rules for coding
agents.

Last consolidated: 2026-08-25

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

The source project is configured as marketing version `1.0.6`, build `2`.
The latest iPad crash report came from TestFlight `1.0.6 (6)`. Before the next
upload, deliberately set and verify the next build number in both app and share
extension targets; do not assume the repository's current build setting matches
the installed TestFlight build.

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
  pages. Cross-store reconciliation remains in the facade.
- `SavedPageImageStore` owns captured source images in Application Support.
  Saved-page metadata and ordinary page selection must not load or rewrite those
  image bytes.
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
| Sentences | Separate SQLite Sentence Library | Paged/query-based access only; normal backup does not carry this heavy database. |
| Favorites and practice progress | Preferences/portable backup models | They remain learning memory when a linked page is removed. |
| Checkpoints | Local snapshots | Same-device recovery, not a portable backup file. |

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

### Page and Sentence Ownership

- Corrected OCR pages, translations, extracted sentence pages, page-created
  practice packs, and page-local notes are page-owned artifacts.
- Favorites, global notes, reusable phrases, and reusable practice progress are
  linked learning memory. Deleting a page must not silently delete them.
- Re-extracting sentences for a page replaces that page's extraction source.
  A sentence is removed only when it has no other source and is not favorited.
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
   practice, AI, or info-card flow to extend.
4. Schedule a documentation audit after a release or substantial refactor. Do
   not recreate parallel restart/handoff files; update this document instead.

## Required Verification

For a normal model/store refactor:

1. `git diff --check`
2. `swift test`
3. `xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build`

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
- `AGENTS.md`: instructions for coding agents.
- `TESTFLIGHT_RELEASE_CHECKLIST.md`: mandatory build-specific automated and
  physical-iPad release gate.
- `PORTABLE_BACKUP_FORMAT.md`: portable backup format contract.
- `VARIANT_MEANING_MIGRATION_2026-08-22.md`: completed one-time dictionary audit.
- `APP_STORE_COPY.md` and `THIRD_PARTY_LICENSES.md`: publication material.

When this file is updated, replace outdated statements rather than appending a
session diary. Keep the current workstream to a small actionable list.
