# Codex Handoff

This file is a quick restart point for future Codex work on Radix. For detailed
rules, always read `PROJECT_CONTEXT.md` first and `UI_INTENT.md` before
navigation or UI-structure changes.

## Current Status

- Branch/workstream: active post-TestFlight / Version 1.1 iteration.
- Product direction: Radix is becoming a linked Page -> Sentence -> Phrase ->
  Character learning graph.
- Browse owns source inspection, especially Dictionary, saved pages, Original
  OCR, Corrected OCR, page editing, and page phrase choosing.
- Study owns kept learning material: Saved Pages, Sentences, Added Phrases,
  Conversation Practices, translations, quizzes, extracted sentence artifacts,
  and deletion of saved pages/artifacts.
- AI Link owns manual and direct Gemini workflows. Saved-page AI tasks should
  reuse the shared AI task flow rather than creating one-off screens.
- Sentence examples are stored in SQLite through `RadixStudyPreferences`; normal
  backup/restore does not include the heavy sentence database. Study > Sentences
  owns fast `.db` transfer.
- Performance is a hard product requirement. Avoid full-library scans in SwiftUI
  render paths, row builders, card opening, backup previews, and search typing.

## Important Decisions

- Sentence cards use `PhraseInfoCard` in sentence mode. They should show the
  whole sentence, English, optional pinyin, read aloud, Phrase button,
  four-character animation pages, favorite, and delete.
- Sentence animation character taps record the character in History and may
  speak it, but must not open another nested preview stack.
- Phrase rows opened from sentence-scoped Phrase Library sheets inspect inside
  that sheet and return directly to the originating sentence.
- The Phrase button in a sentence may merge stored phrase hints with explicit
  on-demand discovery when the sheet opens, but never during row rendering.
- Study lower buttons (`Added Phrases`, `Conversation Practices`, `Sentences`)
  are peer in-place sections. The pinned Study controls stay visible and there
  is no normal `Back to Study` just to switch sections.
- Study section state is one `FocusedStudySection` enum, not multiple booleans.
- Root titles carry screen context: examples are `Browse - Dictionary`,
  `Browse - [page name]`, `Study - Sentences`, and `Study - Favorites`.
  Do not immediately repeat the same section title in the content area.
- Settings exposes user-facing database maintenance as `Optimize Database`.
  Imports/restores may mark optimization as recommended but must not launch it
  automatically.
- Stored data is canonical Simplified Chinese where Radix owns the data;
  Traditional is a display mode.

## Recent Work

- Added History recording for sentence animation characters via context menu and
  then direct tap.
- Converted Study lower sections to behave like in-place content selectors.
- Restored contextual root titles on Mac Catalyst and changed title copy to
  `Study - ...` / `Browse - ...`.
- Unified Study focused section state into one enum to avoid impossible UI
  combinations and duplicated title sync.
- Kept verification passing after each coherent unit.

## Current Dirty-State Warning

At the time this handoff was created, these files were already dirty before the
handoff edits and were not touched by this handoff:

- `Radix.xcodeproj/project.pbxproj`
- `phrases_add.db`

Treat them as user/external changes unless a later task explicitly asks to
inspect or modify them.

## Verification

`PROJECT_CONTEXT.md` currently lists the required verification item:

```sh
git diff --check
```

For Swift/UI changes, continue running the broader proven set when practical:

```sh
swift test
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build
xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'generic/platform=iOS Simulator' CODE_SIGNING_ALLOWED=NO build
```

## Next Steps

1. Continue maintainability refactors in small, verified units.
2. Prefer high-value refactors that remove duplicated state, duplicated UI
   renderers, or full-library work in display paths.
3. Large-file pressure points:
   - `Models/ConversationPracticeModels.swift`
   - `App/FavouritesSections.swift`
   - `ViewModels/RadixStoreDataEdit.swift`
   - `App/FavouritesTab.swift`
   - `Models/PromptModels.swift`
4. Watch performance-sensitive areas:
   - Study Sentences search, paging, and batch delete.
   - Phrase-card Examples and phrase-aware sentence matching.
   - Extracted-sentence reader row construction and canonical sentence lookup.
   - Settings Optimize Database and any phrase-link refresh work.
   - Backup/export flows that serialize large payloads.
5. Keep the reuse-first rule strict: before building new phrase, sentence,
   practice, page artifact, or AI surfaces, search for and extend the existing
   shared component.
