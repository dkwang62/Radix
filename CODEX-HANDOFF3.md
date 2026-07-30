# Codex Handoff 3

This is the current quick restart point for Radix. Before changing the project,
read `PROJECT_CONTEXT.md` as the architecture and workstream source of truth.
Also read `UI_INTENT.md` before navigation or UI-structure work and follow
`AGENTS.md` for verification and commit requirements.

## Current Status

- Branch: `codex/post-testflight-iteration`.
- Workstream: post-TestFlight / Version 1.1 iteration.
- Current version metadata: marketing version `1.0.4`, build `21`.
- Product direction: a linked Page -> Sentence -> Phrase -> Character learning
  graph.
- Browse owns source inspection: Dictionary, saved pages, Original OCR,
  Corrected OCR, page editing, and page phrase choosing.
- `Browse - [page]` / `Browse - Dictionary` is the sole Browse selector for
  Dictionary and saved pages; do not duplicate it with in-content source buttons.
  Selecting a page there opens its Chinese tiles immediately. Camera/capture
  owns album, file, clipboard, and camera intake, then opens the newly created
  page in Browse immediately. There is no top-level Pages destination; the
  selected Browse page toolbar exposes `Study` for page learning, and the
  internal saved-page Study workspace shares the same page `Actions` vocabulary
  instead of exposing a separate `Browse` button. The Study title menu exposes
  this internal route as `Study Pages`.
- Re-running `Extract Sentences` replaces one page's extracted output. Stale
  sentences lose only that page's AI-extraction source; retain a sentence when
  it is favorited or has another source.
- Global Camera routes to the full Camera/capture workbench and opens the
  camera sheet once by default; after dismissal, Camera, Album, and Files
  choices remain visible underneath. Do not reintroduce a Camera-only route.
  Phone and sidebar Search/Camera tiles share `GlobalSearchCameraActionRow` and
  the RootView global action helpers.
- Study owns kept learning material: page learning, Sentences, Added Phrases,
  Conversation Practices, translations, quizzes, extracted-sentence artifacts,
  and deletion of saved pages/artifacts.
- AI Link owns manual and direct Gemini workflows. Saved-page AI tasks should
  reuse the shared AI task flow.
- AI Link's built-in `Sentence Improvement` task can paste/apply an AI answer
  back into the selected saved sentence record.
- Prompt model data stays in `PromptModels.swift`; prompt normalization,
  legacy task repair, and placeholder rendering live in
  `PromptConfigRendering.swift`.
- Sentence examples are SQLite-backed through `RadixStudyPreferences`. Normal
  backup/restore excludes the heavy sentence database; Study > Sentences owns
  fast sentence transfer.
- Performance and app-dismissal responsiveness are hard requirements. Avoid
  full-library or unnecessary persistence/cache work in render paths, search
  typing, card opening, backup previews, scene transitions, and app dismissal.

## Decisions to Preserve

- Sentence cards use `PhraseInfoCard` in sentence mode and retain the whole
  sentence, English, optional pinyin, read aloud, Phrase button,
  four-character animation pages, favorite, sentence-level AI context-menu
  actions, and delete.
- Sentence animation character taps record History and may speak, but do not
  open a nested character/phrase preview stack.
- Phrase rows opened from a sentence-scoped Phrase Library inspect inside that
  sheet and return directly to the originating sentence.
- Sentence phrase discovery is explicit and on demand when the Phrase sheet
  opens. Never run it while rendering a row or merely opening a sentence card.
- On iPhone, shared sentence-list rows show only the selected language
  (Chinese or English), without pinyin or row chevrons, and wrap long portrait
  sentences. The `Study - [section]` title menu is the Study section switcher
  on every platform; do not duplicate those choices as in-content dashboard
  buttons.
  Keep the title menu and History strip visible across Study sections, including
  embedded Added Phrases and Conversation Practice.
  Phone row favorite/overflow actions live in context/tool menus unless
  selection mode needs checkboxes. iPad and Mac keep the richer pinyin row.
- Conversation Practices should mirror Study Sentences on every platform: no
  bottom action bar, no framed practice card shell, no local Translate Quiz, and
  Flashcards/Quick Quiz in the compact tools menu above the sentence list.
- Conversation practice progress models live in
  `ConversationPracticeProgressModels.swift`; keep progress serialization there.
- Sentence-based Study surfaces share a default 10-row page size. Study
  Sentences uses one compact source menu for All/Favorites/From Pages/From
  Practice instead of a row of source buttons. Its tools menu keeps destructive
  sentence actions inside a nested `Delete...` menu, and single-sentence delete
  requires confirmation.
- `Added Phrases`, `Conversation Practices`, and `Sentences` are peer in-place
  Study sections selected from the root title menu. They share one
  `FocusedStudySection` enum, keep pinned Study controls visible, and do not
  show a normal `Back to Study`.
- Root titles carry context, including `Browse - Dictionary`,
  `Browse - [page name]`, and `Study - Sentences`. Do not immediately repeat
  the same title in the content area.
- Settings exposes one user-facing `Optimize Database` action. Imports and
  restores may recommend optimization but must not launch it automatically.
- Data maintenance code lives in `RadixStoreDataMaintenance.swift`; keep
  Character Studio edit/import behavior in `RadixStoreDataEdit.swift`.
- Radix-owned Chinese data is stored canonically in Simplified Chinese;
  Traditional Chinese is a display mode.
- `flushPendingDataEditAutoSave()` must remain pending-only. Scene transitions
  with no Character Studio edit must not trigger persistence and cache refresh;
  doing so during iOS background snapshots can cause `0x8BADF00D` watchdog
  termination.
- Preserve persisted identifiers, cross-platform behavior, data integrity, and
  the existing reuse-first component policy.

## Work Completed

- Deferred full sentence phrase discovery from normal display paths and made
  phrase lookup comprehensive only when explicitly requested.
- Kept sentence and practice History behavior bounded and normalized, including
  direct/context-menu History recording for sentence animation characters.
- Converted Study lower sections into in-place selectors, retained pinned
  controls, unified their state, and removed obsolete section back renderers.
- Restored contextual root titles on Mac Catalyst and aligned title copy across
  Browse and Study.
- Removed the local Conversation Practice Translate Quiz and moved remaining
  practice drills out of the iPhone bottom bar.
- Simplified user-facing database optimization wording and avoided automatic
  heavy phrase-link refresh work.
- Added the app version/build to Settings > About.
- Prevented idle Character Studio autosave work during app dismissal.
- Bumped the TestFlight build from 11 to 12.

Recent commits, newest first:

- `60e0c74` Bump TestFlight build to 12
- `a503dc4` Avoid idle autosave work during app dismissal
- `32ff0be` Remove obsolete Study back controls
- `6c42f0a` Add Codex handoff summary
- `d85c880` Show app version in settings
- `39b3187` Unify Study section state
- `f2fe829` Show Study section in root title
- `ceeb73d` Show contextual title on Catalyst

## Dirty Worktree Warning

The following files are currently dirty and predate this handoff work:

- `phrases_add.db`

Treat this as a user/external change. Do not discard, normalize, stage, or
commit it unless a later task explicitly establishes its intended changes.

## Verification

Required baseline:

```sh
git diff --check
swift test
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
```

For release work and platform-sensitive UI/data changes, also run:

```sh
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

The latest completed AI Link update passed `git diff --check`, all 91 portable
Swift tests, Mac Catalyst compilation, and generic iOS Simulator compilation.

## Next Steps

1. Continue maintainability refactors as small, coherent, verified commits.
2. Prefer changes that eliminate duplicated state/renderers or remove
   full-library work from display paths without changing user behavior.
3. Large-file pressure points remain:
   - `Models/ConversationPracticeModels.swift`
   - `App/FavouritesSections.swift`
   - `ViewModels/RadixStoreDataEdit.swift`
   - `App/FavouritesTab.swift`
   - `Models/PromptModels.swift`
4. Watch performance-sensitive paths:
   - Study Sentences search, paging, selection, and batch deletion.
   - Phrase-card Examples and phrase-aware sentence matching.
   - Extracted-sentence reader paging and canonical sentence lookup.
   - Settings Optimize Database and phrase-link maintenance.
   - Backup/export serialization and app lifecycle transitions.
5. Before adding phrase, sentence, practice, saved-page artifact, or AI UI,
   search for and extend the existing shared component.
6. Update `PROJECT_CONTEXT.md` in every completed work-unit commit; keep this
   handoff aligned when the workstream meaningfully changes.
