# Radix Project Context

This is the concise engineering hand-off and current source of truth for ongoing
Radix work. Read it before changing the project. Update it in the same commit as
each completed work unit. Git remains the detailed historical record; this file
describes the present state and immediate direction.

Last reviewed: 2026-06-27

## Product and Platform Scope

Radix is one SwiftUI application targeting iPhone, iPad, and Mac Catalyst. The
iPhone interaction model is normally the behavioral source of truth, while
larger platforms adapt layout for available space without diverging in labels,
features, data formats, or workflow semantics.

The project is also being prepared for an eventual Android implementation. New
business rules, persisted identifiers, backup contracts, and storage interfaces
should therefore be platform-neutral where practical. SwiftUI, StoreKit,
AVFoundation, and Apple file-picker behavior remain adapter-layer concerns.

## Current Architecture

### Application shell

- `App/RadixApp.swift` creates one `RadixStore` and one `EntitlementManager`.
- `RadixStore` remains the observable facade consumed by existing SwiftUI views.
- Platform-specific layout decisions use `RadixPlatform`; they must not create
  different data behavior between iPhone, iPad, and Catalyst.

### Store state and adapters

`ViewModels/RadixStore.swift` owns repositories, aggregate state objects, caches,
and compatibility properties needed by existing views. It has been reduced from
roughly 1,550 lines to about 441 lines.

State is divided into focused value types:

- `RadixNavigationState` and `RadixSearchState`
- `RadixDataEditFormState` and `RadixDataWorkspaceState`
- `RadixBrowseFilterState`, `RadixBrowseGridState`, and `RadixBrowseHighlightState`
- `RadixCharacterContextState`, `RadixLineageState`, and `RadixRootExplorerState`
- `RadixCollectionState` and `RadixUserLibraryState`
- `RadixAILinkState` and `RadixAIProviderState`
- `RadixDataAuditState` and `RadixPresentationState`

Navigation, search, Character Studio form, Browse filter/grid/highlight, saved
page collection, and presentation adapters are now co-located with their state
definitions. Browse filter reset/recompute and collection-selection side effects
live with their adapters. Continue this pattern only where it materially clarifies
the remaining state: the central store should own state, while each state file
exposes its related compatibility adapters.

### Domain behavior

Large behavior groups have been extracted from the central store into
`RadixStore*` extensions:

- lifecycle and profile restoration
- navigation and roots/breadcrumb behavior
- search, grid, and image-phrase behavior
- collections, favorites, and phrase-file behavior
- Character Studio editing and helpers
- AI provider and prompt behavior

Do not move domain behavior back into `RadixStore.swift`.

### Data and persistence

- Character dictionary: JSON base data plus `component_map_changes.json` overlay.
- Phrases: bundled SQLite plus the user-added phrase database.
- Portable backup: `UnifiedPackage` schema 5, with legacy backup decoding retained.
- `RadixPreferenceKey` is the canonical list of stable persisted identifiers.
- `RadixPreferenceStore` is the platform-neutral storage boundary.
- Apple persistence uses `RadixPreferences`, backed by `UserDefaults`.
- `RadixStore`, `EntitlementManager`, and the phrase database location manager
  accept an injected preference store.

Never change an existing preference key, enum raw value, backup field, or review
status without an explicit migration and compatibility test.

### Portable core

`Package.swift` defines `RadixCore`, which contains platform-neutral models and
compatibility contracts. Current portable contracts include:

- backup and profile models/codecs
- phrase-review status behavior
- navigation, tab, script-filter, and restore-mode identifiers
- preference keys and the preference-storage interface

The portable test suite currently contains 18 tests across seven suites.

## Active Workstream

The central-store maintainability refactor is complete. Current product work is
restoring unobtrusive navigation guidance: optional labels plus first-use,
dismissible destination explanations that experienced users can hide or replay.
Navigation help presentation belongs at `RootView`; do not attach popover or
context-menu presentation containers to the five equal-width tab buttons because
those wrappers can collapse the SwiftUI HStack to one visible destination.
On iPhone, iPad, and Mac Catalyst, ordinary navigation only changes destination;
help opens exclusively through a long press so it never obscures routine navigation.
Each destination guide should name concrete user actions and examples, not merely
summarize the section.
Every guide uses `Why it matters` followed by `What you can do`; AI Link is
specifically framed as extending beyond traditional dictionary coverage through
contextual translation, deeper explanation, emerging concepts, and phrase extraction.
That purpose-first framing is shared by the AI Link screen, welcome guidance,
task descriptions, Browse extraction/translation sheets, and glossary; describe
the learner outcome before copy/paste, API, or other implementation mechanics.
`Icons & Labels` is the explicit startup default navigation style; launch
normalizes the saved preference back to that style so an old `Icons Only`
choice cannot silently persist across app restarts. `Icons Only` remains an
experienced-user option within the current session and must not become the
fallback accidentally.
Advanced Exports are a code and structured-data foundation for authoring software
with AI coding agents; describe them as distinct from backup and ordinary transfer.
Search examples visibly teach exact English matching: `=water` matches `water`
without broadening to meanings such as `waterproof`.
Raw Apple stroke-symbol sequences are not presented as searchable examples;
Apple Stroke input is documented only as a keyboard method for composing a
completed Chinese character before searching.
Saved OCR pages now retain optional original/reviewed OCR provenance. `Check OCR`
prepares a structured ChatGPT handoff using the saved page characters as the
main input, with Radix-recognized characters, nearby dictionary phrases, and the
saved reference image as supporting evidence. The goal is to spot anomalies that
suggest capture/OCR mistakes in the page characters, not to replace the page
input with raw image OCR. The user pastes ChatGPT's structured response and
compares it with the original. Approval creates a separately identified corrected
saved page linked to the original; the original page is never modified. New OCR
pages retain an optional review-sized source image in addition to the normal UI
thumbnail.
When a Gemini API key is configured, `Check OCR` additionally offers an
automatic multimodal review using the same prompt and saved image. Its response
creates and opens a corrected saved page immediately.
Saved-page AI actions are grouped by task—Check OCR, Extract Phrases,
Translate Page, and Create Quiz. Each task consistently offers copy/paste with
ChatGPT or an automatic Gemini route. A missing-key automatic choice becomes
`Set Up Gemini API Key…`, navigates to Settings with Private API Keys expanded,
and preserves `Back to Browse`. Setup is described as enabling all page AI
automation, not just one task.
All four also exist as editable saved-page templates in AI Link. Browse OCR
review renders the `Check OCR` template with saved page characters,
recognized/unrecognized characters, and nearby phrase evidence rather than a
separate hard-coded instruction. Legacy `Check OCR` templates that described
`ORIGINAL OCR` normalize to the saved-page-character wording so placeholder raw
OCR cannot become the primary AI input.
AI Link exposes one task per user goal. The former API-only phrase task is
removed; `Extract Phrases` supports both copy/paste and automatic Gemini
execution without appearing twice.
OCR correction no longer has a proposal-approval screen. Automatic Gemini
review creates and opens the corrected Browse page immediately; copy/paste uses
one `Paste Answer and Create Corrected Page` action. The original OCR page is
always retained as the reversible source record.
Corrected pages retain the longest possible prefix of the original 11-character
name and add a unique numeric suffix such as `1` or `2`.
The corrected source remains Chinese, while change reasons, confidence, and
uncertainty explanations are explicitly requested in English.
Study uses its four summary tiles as the section selectors. Recent and Favorites
must not be repeated as a segmented picker above the review grid.
On iPad those four tiles use an explicit two-column layout so all labels remain
readable; phone and Mac retain their adaptive layouts.
Added Phrases review includes a visible shortcut that creates an `AI Review`
saved page from all current unreviewed, non-base added phrases, then opens that
page in Browse with a `Back to Study` return path. This action does not mark,
accept, reject, or delete the source phrases. The Batch menu is reserved for
bulk status/deletion actions rather than hiding this workflow. The eligibility,
ordering, page name, and newline-delimited source text are portable
`AddedPhraseReviewRules` behavior with compatibility tests so Android can share
the same rule.
On Mac Catalyst the Added Phrases classification sheet shows 28 tiles per page
(4 columns × 7 rows) to avoid internal grid scrolling, which can momentarily
hang while users scroll the sheet.
Content-driven cross-tab navigation uses the existing single-level return
context. Destinations show a named return button (`Back to Study`, `Back to My
Data`, and so on); manually choosing a primary tab clears that context.
Saved Browse pages use one labelled `Actions` menu for editing, OCR review,
phrase selection, translation, and AI workflows. The source chooser remains
separate navigation; only the script toggle and Read Aloud remain permanently
visible page controls.
Browse source actions include text from the clipboard, image from the clipboard,
album import, file import, and saved-page selection. Clipboard text and image
actions explicitly tell the user to copy the source content first. Clipboard
images use the same OCR page creation path as camera, album, and file images.
Entering Browse selects the saved page with the newest viewed-or-created date;
the same selection is established during startup because the app launches on
Browse without invoking a tab transition. Dictionary is the fallback only when
no saved pages exist.
Saved-page name normalization, corrected-name suffixing, and most-recent
selection live in portable `SavedPageRules` with compatibility tests. SwiftUI
only supplies actions; one shared Browse gateway handles missing Gemini keys
for OCR, phrase extraction, translation, and AI quiz generation.
The OCR, extraction, and translation task menus share the same method vocabulary:
`Use Another AI App` or `Run Automatically in Radix`. The first method choice
shows one concise orientation, then continues the chosen action; `How Radix Uses
AI` reopens it without adding permanent screen text. The orientation uses a
sheet with pinned actions on every platform so iPad cannot truncate the
description or lose the continuation control.
Copy-and-paste is the durable fallback and remains visible even when a Gemini
key is saved. Automatic OCR, extraction, translation, or quiz generation
failures offer a clear fallback because a valid key does not guarantee Gemini
service availability.
Manual ChatGPT handoff copies the full prompt to the pasteboard and opens the
base ChatGPT URL only. Do not pass Chinese page text through ChatGPT URL query
parameters; that path has corrupted CJK text into placeholder glyphs on iPad.
Check OCR's manual handoff must not be hardcoded to ChatGPT: the sheet labels
and opens the configured default AI app, while keeping copy/paste available for
ChatGPT, Gemini, or another service.
The OCR review sheet shows one primary manual action, `Open <default AI>`, which
copies the instruction and opens the AI app. After that action is tapped, the
instruction section collapses so the remaining next step is pasting the AI
answer to create the corrected page. Do not reintroduce separate visible
`Copy Instruction` or `Copy Image` buttons beside the primary action.
Create Quiz is page-only and uses the same two-method menu as the other saved
page AI tasks. `Use Another AI App` copies and opens the editable quiz template
so the user can practice in ChatGPT, Gemini, or another service without an API
key. `Run Automatically in Radix` asks Gemini for structured quiz JSON, then
Radix presents the questions one at a time, keeps answers hidden until the user
taps an option, and immediately marks the answer correct or wrong with an
English explanation. The quiz sheet must be scrollable and padded below the
toolbar so page titles, instructions, options, and feedback are never obscured.
If the automatic route is entered without a key, Radix explains the issue and
offers both `Set Up Gemini API Key` and a local dictionary-backed fallback quiz.
The setup action uses the shared Browse-to-Settings API-key path, reveals Private
API Keys, and preserves `Back to Browse` instead of leaving the user to find
Settings manually.
Navigation guidance and the welcome screen use one canonical division of work:
Browse inspects the dictionary or captured pages; Study reviews what the user
kept; AI understands or transforms material; My Data protects, transfers, or
exports the user's work.
Local snapshots are presented as `Checkpoints` to avoid colliding with backup
language. Checkpoints live at the bottom of Study as a safety-net section after
the main review content. The section has one Create Checkpoint action and a
scrollable checkpoint list with roughly three rows visible; tapping a row is the
return action after confirmation, so there is no separate restore menu competing
with the learning content. Returning to a checkpoint always leaves the user in
Study, even if the checkpoint was created while another tab was active.
Study includes a compact `Backup files` bridge to My Data so users can still
distinguish local learning recovery from portable file protection.
My Data’s `Protect & Recover` screen owns Backup File actions only. Backup
history stores lightweight file metadata and shows filenames; a selected backup
file restores immediately when the saved path is still readable, otherwise
Radix falls back to the file picker with the chosen Merge/Replace intent
preserved. My Data links back to Study for Checkpoints instead of duplicating
the checkpoint controls.
Backup File actions keep the same three choices across iPhone, iPad, and Mac:
Create Backup, Merge Backup, and Replace from Backup. iPhone and iPad use a
readable two-row arrangement with Create Backup above Merge/Replace; Mac can
use the wider three-card row. My Data content is width-capped inside its column
so long explanations and action cards do not visually spill to the screen edge.

## Next Three Tasks

1. Manually verify the saved-page `Actions` menu on iPhone, iPad, and Mac
   Catalyst, including conditional `Check OCR`.
2. Usability-test `Check OCR` with clear, ambiguous, and incorrect captures,
   including the collapsed manual handoff and structured-response workflow.
3. Perform a short regression for backup restore, Browse saved pages, phrase
   classification, and My Data flows.

Stop decision: the remaining `RadixStore` content is legitimate state ownership,
caches, dependencies, and compatibility plumbing. Repository protocols are not
being added until a concrete alternate repository implementation needs them.

## Established Engineering Rules

- Commit every coherent, build-verified unit; normally one commit per task.
- Preserve user changes and unrelated dirty-worktree content.
- Use the iPhone behavior as the cross-platform truth unless screen size truly
  requires a different arrangement.
- Keep customer-facing labels and navigation semantics consistent everywhere.
- Prefer portable models and pure business rules over Apple-framework coupling.
- Use injection at persistence/service boundaries instead of hard-wiring stores.
- Keep `RadixStore` as a facade during migration so views do not churn needlessly.
- Co-locate state adapters with their state definitions.
- Keep backup restore transactional: validate first and preserve existing data
  when acquisition, decoding, or compatibility checks fail.
- Never block the main actor while waiting for iCloud or file coordination.
- Remove code only when references and platform builds confirm it is dead.
- Do not commit Xcode-generated localization-catalog churn unless intentional.

## Required Verification

For normal model/store refactors:

1. `git diff --check`
2. Portable Swift package tests
3. Mac Catalyst build with code signing disabled

Before a release or after platform-sensitive UI/data changes, also build the
generic iOS target, which covers the universal iPhone/iPad application. Simulator
launch failures caused by CoreSimulatorService are environmental and should be
reported separately from compilation failures.

Final refactor verification on 2026-06-25:

- 15/15 portable tests passed across six suites.
- Universal generic iOS build passed, covering iPhone and iPad.
- Mac Catalyst build passed.
- All 230 Swift source files are represented in the Xcode project.
- Conservative unused-private-declaration audit found no remaining candidate.

## Recent Milestones

- Extracted focused state objects from the former monolithic `RadixStore`.
- Moved domain behavior into dedicated store extensions.
- Isolated lifecycle startup and profile restoration.
- Removed confirmed dead code and audited Xcode source membership.
- Centralized and tested persisted preference keys.
- Moved navigation, script, and restore contracts into `RadixCore`.
- Added a platform-neutral preference-storage boundary.
- Co-located navigation, search, and Character Studio form adapters.
- Co-located Browse filter adapters and their recompute side effects.
- Co-located Browse grid and saved page collection adapters.
- Co-located presentation and Browse highlight adapters.
- Completed the final dead-code/source-membership audit and platform build matrix.
- Restored optional navigation labels and progressive first-use destination help.

## Updating This File

At the end of each completed work unit:

1. Update architecture statements affected by the change.
2. Replace the active workstream and next tasks when priorities move.
3. Add only significant milestones; do not append a verbose session diary.
4. Update test counts and verification expectations when they change.
5. Commit this file with the code it describes.
