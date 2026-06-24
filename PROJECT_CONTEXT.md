# Radix Project Context

This is the concise engineering hand-off and current source of truth for ongoing
Radix work. Read it before changing the project. Update it in the same commit as
each completed work unit. Git remains the detailed historical record; this file
describes the present state and immediate direction.

Last reviewed: 2026-06-24

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

The portable test suite currently contains 13 tests across five suites.

## Active Workstream

The central-store maintainability refactor is complete. Current product work is
restoring unobtrusive navigation guidance: optional labels plus first-use,
dismissible destination explanations that experienced users can hide or replay.
Navigation help presentation belongs at `RootView`; do not attach popover or
context-menu presentation containers to the five equal-width tab buttons because
those wrappers can collapse the SwiftUI HStack to one visible destination.
On iPad and Mac Catalyst, ordinary sidebar navigation only changes destination;
help opens exclusively through a long press so it never obscures routine navigation.
The iPhone may still offer each guide on first visit as progressive onboarding.
Each destination guide should name concrete user actions and examples, not merely
summarize the section.
Every guide uses `Why it matters` followed by `What you can do`; AI Link is
specifically framed as extending beyond traditional dictionary coverage through
contextual translation, deeper explanation, emerging concepts, and phrase extraction.
That purpose-first framing is shared by the AI Link screen, welcome guidance,
task descriptions, Browse extraction/translation sheets, and glossary; describe
the learner outcome before copy/paste, API, or other implementation mechanics.
`Icons & Labels` is the explicit default navigation style; `Icons Only` remains
an experienced-user option and must not become the fallback accidentally.
Advanced Exports are a code and structured-data foundation for authoring software
with AI coding agents; describe them as distinct from backup and ordinary transfer.

## Next Three Tasks

1. Manually verify the navigation tips and `Icons & Labels`/`Icons Only` setting
   on iPhone, iPad, and Mac Catalyst.
2. Perform a short regression for backup restore, Browse saved pages, phrase
   classification, and My Data flows.
3. Choose the next user-facing feature or defect from actual usage rather than
   restarting structural refactoring.

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

Final refactor verification on 2026-06-24:

- 13/13 portable tests passed across five suites.
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
