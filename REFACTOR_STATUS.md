# Radix maintainability refactor — completed status

**Build status: CLEAN (PaywallView split)**
Last verified build: `xcodebuild -project Radix.xcodeproj -scheme Radix -destination generic/platform=iOS build`

---

## Post-checkpoint update

`FilterGridTab.swift` has now been split into focused Browse extensions:

- `FilterGridTab.swift` — state, layout shell, sheets, alerts
- `BrowseSourceBar.swift` — source disclosure bar, selected image actions, read-aloud controls
- `BrowseSourcePicker.swift` — dictionary/manual/image source picker rows
- `BrowseDictionaryGrid.swift` — dictionary grid content, paging footer, swipe gesture, grid controls
- `BrowseImageGrid.swift` — saved-image grid content and simplified/traditional display text
- `BrowseScrollRestoration.swift` — browse return flow, preview restoration, tile anchors
- `BrowseCollectionEditing.swift` — manual collection creation and image collection editing

The iOS build was verified clean after this behavior-based split.

`CharacterPhraseLookupSection.swift` has also been split so the reusable phrase views live in focused files:

- `CharacterPhraseLookupSection.swift` — phrase lookup list, row presentation, selection/dismiss flow
- `PhraseInfoCard.swift` — reusable detailed phrase card with animation tiles and note editing
- `PhraseSummaryTile.swift` — compact reusable phrase summary tile

The iOS build was verified clean after this continuation split.

`SmartSearchTab.swift` has now been split into focused Smart Search extensions:

- `SmartSearchTab.swift` — state, body shell, top-level search/reset actions
- `SmartSearchHeader.swift` — search field, history menu, clear/search controls
- `SmartSearchResults.swift` — results header, grid, empty-results state
- `SmartSearchPhraseDrilldown.swift` — phrase length picker, phrase rows, character buttons
- `SmartSearchPreview.swift` — phone preview and phrase info sheet routing
- `SmartSearchExamples.swift` — starter examples and Apple stroke keyboard help

The iOS build was verified clean after this split.

`RootView.swift` has now been split into focused root-shell extensions:

- `RootView.swift` — global app shell, sheet/import/export modifiers, scene lifecycle
- `RootViewDataTransfer.swift` — profile and add-phrases import/export actions
- `RootPhoneView.swift` — compact phone navigation, tab bar, phone title/content routing
- `RootDetailPane.swift` — iPad split view and detail-pane route switching
- `RootSidebar.swift` — sidebar navigation, settings entry, active preview panel

The iOS build was verified clean after this root coordinator split.

`CapturePhraseDiscoveryModels.swift` and `CapturePhraseDiscoveryViews.swift` have now been split by model/tooling and UI responsibility:

- `CapturePhraseDiscoveryModels.swift` — core phrase discovery value types and parse/import result structs
- `CapturePhraseDiscoveryTools.swift` — selection, merge, import preparation, and read-result helpers
- `CapturePhraseMessages.swift` — capture/discovery status and helper messages
- `CaptureWorkflowModels.swift` — phrase-import workflow step models and parser source metadata
- `PhraseDiscoveryParser.swift` — AI/clipboard phrase answer parsing and validation
- `CapturePhrasePromptBuilder.swift` — prompt generation for AI phrase parsing/discovery
- `CapturePhraseDiscoveryViews.swift` — main phrase import workflow view
- `PhraseDiscoverySummaryViews.swift` — summary grid, workflow progress, and result lists
- `PhraseDiscoveryInputViews.swift` — phrase answer input panels
- `PhraseDiscoveryRows.swift` — candidate/result rows and reusable chips/fields

The iOS build was verified clean after this capture phrase discovery split.

`AILinkView.swift` has now been split into focused AI Link extensions:

- `AILinkView.swift` — state, route mode selection, active subject/collection computed state, root body
- `AILinkPromptGeneration.swift` — prompt-generation task list, task subject labels, image collection picker
- `AILinkTemplateEditor.swift` — epilogue editors, task template editor rows, template lookup helpers
- `AILinkPromptOutput.swift` — generated prompt preview, copy/open actions, AI preset launch flow

The iOS build was verified clean after this AI Link split.

`DataEditTab.swift` has now been split into focused My Data extensions:

- `DataEditTab.swift` — state, root body, exporter/importer modifiers, backup restore callbacks
- `DataEditHeader.swift` — help and advanced-export toggle header
- `DataEditBackupSection.swift` — backup/restore actions, backup preview routing, portable backup creation
- `DataEditPremiumExports.swift` — advanced export section and gated export option wiring
- `DataEditBackupEntries.swift` — changed phrase entry filtering and active phone preview context

The iOS build was verified clean after this My Data split.

`ComponentsExplorerShell.swift` has now been split into focused Components Explorer extensions:

- `ComponentsExplorerShell.swift` — state, root body, toolbar/help, lifecycle and filter-change hooks
- `ComponentsExplorerSections.swift` — derivatives, shared peers, initial grid, row/cell rendering
- `ComponentsExplorerFilters.swift` — root filter count/title, filter sheet, radical/structure pickers
- `ComponentsExplorerNavigation.swift` — pivoting, seed sync, reload, breadcrumb stepping helpers

The iOS build was verified clean after this Components Explorer split.

`CharacterInfoCard.swift` has now been split into focused character card extensions:

- `CharacterInfoCard.swift` — state, initializers, root body, standard card composition
- `CharacterInfoCardHeader.swift` — header row, favorite button, tier button, usage tile
- `CharacterInfoCardComponents.swift` — structure chip, component grid, component popover opening
- `CharacterInfoCardGuides.swift` — chip/tier guide popover bindings and content
- `CharacterInfoCardText.swift` — display strings, tier labels, definition/etymology/notes block
- `CharacterInfoCardStyle.swift` — sizing, chips, fonts, style helpers

The iOS build was verified clean after this character info card split.

`QuickCharacterEditorView.swift` has now been split into focused quick-edit extensions:

- `QuickCharacterEditorView.swift` — state, header, loading lifecycle, keyboard toolbar
- `QuickCharacterEditorPrompt.swift` — new-character prompt and custom-entry creation
- `QuickCharacterEditorForm.swift` — fixed/scrollable form shells and error presentation
- `QuickCharacterEditorFields.swift` — dictionary field layout and reusable field wrappers
- `QuickCharacterEditorNotes.swift` — notes editor, placeholder, sizing
- `QuickCharacterEditorActions.swift` — delete/revert/cancel/save actions

The iOS build was verified clean after this quick character editor split.

`AddPhraseSheet.swift` has now been split into focused phrase-add views:

- `AddPhraseSheet.swift` — sheet shell, mode/step routing, added-phrase bookkeeping
- `AddPhraseInputForm.swift` — manual phrase entry form, validation, save action
- `AddPhraseExtractForm.swift` — AI paste/import flow and import summary handling
- `AddPhraseReview.swift` — added-phrase review list, empty state, return/add-more actions

The iOS build was verified clean after this Add Phrase split.

`CharacterAnimationSharing.swift` has now been split into focused animation sharing helpers:

- `CharacterAnimationSharing.swift` — public copy/share/open/link helpers and Chinese-character validation
- `CharacterAnimationSharePresenter.swift` — UIKit/AppKit share sheet presentation
- `HanziWriterGIFExporter.swift` — stroke-data fetch, frame rendering, GIF writing
- `HanziSVGPathParser.swift` — Hanzi Writer SVG path tokenizing and `CGPath` parsing

The iOS build was verified clean after this animation sharing split.

`DataBackupPreviewSection.swift` has now been split into focused backup preview extensions:

- `DataBackupPreviewSection.swift` — section shell, disclosure routing, phrase preview sheet
- `DataBackupPreviewLists.swift` — saved images, character grids, phrase grids, sorting and thumbnails
- `DataBackupPreviewSummaries.swift` — favorites, AI templates, and app-state summaries
- `DataBackupPreviewActions.swift` — base phrase revert action and phrase preview presentation

The iOS build was verified clean after this backup preview split.

`PhraseInfoCard.swift` has now been split into focused phrase card extensions:

- `PhraseInfoCard.swift` — state, sheet/lifecycle hooks, root card composition
- `PhraseInfoHeader.swift` — phrase title, favorite/edit controls, pinyin/done row
- `PhraseInfoControls.swift` — simplified/traditional toggle and add-phrase button
- `PhraseInfoAnimation.swift` — character animation grid, variant choice, character selection
- `PhraseInfoNotes.swift` — meaning text, note editor, save/cancel handling

The iOS build was verified clean after this phrase info card split.

`CharacterDetailView.swift` has now been split into focused detail-view extensions:

- `CharacterDetailView.swift` — scroll shell, toolbar, lifecycle refresh hooks, phrase table routing
- `CharacterDetailHeader.swift` — compact/regular character headers and variant buttons
- `CharacterDetailLineage.swift` — lineage controls, component/derivative strips, lineage cells
- `CharacterDetailActions.swift` — notes, phrase table, and components action buttons

The iOS build was verified clean after this character detail split.

`FavouritesTab.swift` has now been split into focused Favorites views:

- `FavouritesTab.swift` — tab shell, environment/state, phone phrase sheet
- `FavouritesHeader.swift` — import/export buttons and helper copy
- `FavouritesSections.swift` — scroll content and character/phrase sections
- `FavouritesCells.swift` — character cells, phrase row helper, grid sizing, saved-date labels
- `FavouritesPhrasePresentation.swift` — phrase preview routing and sheet binding
- `ProLockedView.swift` — reusable Pro feature lock view

The iOS build was verified clean after this Favorites split.

`PaywallView.swift` has now been split into focused paywall extensions:

- `PaywallView.swift` — NavigationStack shell, environment/state, background
- `PaywallContent.swift` — hero, feature list, benefits, hero chips
- `PaywallPlans.swift` — plan loading states, StoreKit product cards, product labels
- `PaywallFooter.swift` — restore purchases, debug Pro toggle, error/renewal footer

The iOS build was verified clean after this paywall split.

---

## Summary

The full maintainability refactor is complete. `RadixStore.swift` was reduced from **4,204 → 1,078 lines** (−74%) by extracting every logical domain into focused `extension RadixStore` files. The Services layer was similarly split. Total line count across the codebase is stable — no logic was removed, only reorganised.

---

## ViewModels layer — final state

### RadixStore.swift (1,078 lines) — what remains

This is the irreducible core. Do not attempt to split further without an architectural change.

| MARK section | Lines | Notes |
|---|---|---|
| Navigation State | ~17 | `@Published` vars — must stay on main class |
| Search State | ~8 | `@Published` vars |
| DataEdit (Character Studio) State | ~25 | `@Published` vars |
| Browsing & Filter State | ~136 | `@Published` vars |
| Computed Result Sets | ~20 | Computed vars over published state |
| User Settings & Variances | ~24 | `@Published` vars |
| iPhone UI State | ~3 | `@Published` vars |
| AI Context State | ~11 | `@Published` vars |
| Repositories & Helpers | ~59 | Repository instances, keys, cache vars, nested structs |
| Core Lifecycle | ~70 | `init`, `setup`, `deinit` — orchestrates all repositories |
| Filter Logic & Caching | ~174 | Grid build/recompute — tightly coupled to published state |
| Lineage Logic | ~31 | Too small and coupled to extract |
| Private Utilities | ~428 | Helpers called from multiple extension files; no better singular home |

### Extension files (13 files, 3,132 lines)

| File | Lines | Domain |
|---|---|---|
| `RadixStoreDataEdit.swift` | 542 | Character Studio CRUD, import/export, phrase editing, variance check |
| `RadixStoreNavigation.swift` | 377 | `select`, `preview`, `browsePreview`, all `goTo*`/`enter*`/`returnFrom*`, quick editors, AI dispatch |
| `RadixStoreSearch.swift` | 333 | `performSearch`, `clearSearch`, phrase accessors, favorites toggle, thin component accessors |
| `RadixStoreImagePhrase.swift` | 327 | Image character tap, highlight anchor/restore, browse memory, scroll targeting |
| `RadixStoreDataEditHelpers.swift` | 323 | Form apply/build/clear, dictionary refresh, entry merge, phrase utilities, profile export/import, `refreshPhraseBackedViews`, `syncDataEditPhraseCaches` |
| `RadixStoreRootsBreadcrumb.swift` | 258 | Remembered Bar push/remove/toggle/step, activation routing, breadcrumb persistence, seed from favorites |
| `RadixStoreGrid.swift` | 239 | Grid recompute, filter predicates, sort comparators, phrase lookup helpers, image phrase highlight plumbing, text normalization |
| `RadixStoreCollections.swift` | 194 | `CharacterCollection` CRUD, selection, persistence |
| `RadixStorePrompts.swift` | 185 | Prompt config mutations, task CRUD, `promptText` overloads, `promptRenderContext` |
| `RadixStoreFavorites.swift` | 116 | Load/persist/apply favorites and phrase favorites, `setFavorite`, `persistFavoritePhraseDates` |
| `RadixStoreAI.swift` | 116 | Task selection for character launch, AI URL construction, Mac clipboard paste |
| `RadixStoreRootsCache.swift` | 92 | `loadSharedComponentPeers`, `loadSharedPeersByComponent`, `loadRootDerivatives`, `rootDerivatives` |
| `RadixStorePhraseFile.swift` | 30 | `setAddPhrasesFile`, `restoreDefaultAddPhrasesFile`, `exportAddPhrasesDB` |

---

## Services layer — final state

### Already split (do not redo)

**ComponentRepository.swift** (506 lines) — coordination only. Helpers already extracted:
- `ComponentScriptClassifier.swift` (71 lines)
- `ComponentDecompositionParser.swift` (~60 lines)
- `ComponentOverlayBuilder.swift` (104 lines)
- `ComponentFrequencyProvider.swift` (92 lines)
- `ComponentIndexBuilder.swift` (88 lines)
- `ComponentSearchEngine.swift` (126 lines)

**PhraseRepository.swift** (480 lines) — clean reads/writes/lifecycle. Helper extracted:
- `PhraseQueryRunner.swift` (67 lines) — stateless SQLite plumbing
- `PhraseAddDatabaseLocationManager.swift` (188 lines)
- `PhraseAddDatabaseSchema.swift` (~50 lines)
- `PhrasePinyinSearchIndex.swift` (~60 lines)

**DataExport** split:
- `DataExportService.swift`
- `DataExportDatabaseBuilder.swift` (109 lines)
- `DataExportArchiveBuilder.swift` (266 lines)
- `StoredZipArchive.swift` (117 lines)

**Stroke support** split:
- `StrokeRepositories.swift` (177 lines)
- `StrokeSynthesisEngine.swift` (150 lines)
- `StrokeSynthesisSupport.swift` (189 lines)
- `StrokePathTransformer.swift` (108 lines)
- `StrokeIDSParser.swift` (~60 lines)

### Remaining Services — at natural floor, do not split

| File | Lines | Verdict |
|---|---|---|
| `DataExportArchiveBuilder.swift` | 266 | No clean seam remaining |
| `StrokeSynthesisSupport.swift` | 189 | Already small, no obvious split |
| `EntitlementManager.swift` | 178 | iOS/StoreKit specific, fine as-is |

---

## Access level changes made

Many `private` and `private(set)` declarations were changed to `internal` (the default) throughout `RadixStore.swift` to allow access from extension files in separate files. This is expected and correct — Swift's `private` is file-scoped, not type-scoped. All symbols remain internal to the module; nothing is exposed publicly. Future developers should be aware that most properties and methods on `RadixStore` are intentionally internal rather than private.

---

## What was NOT done (and why)

- **SwiftUI View splits** — Already done before this refactor. `FilterGridTab.swift` (720 lines) is the largest remaining View but splitting it requires careful SwiftUI state threading.
- **SearchCoordinator as a separate class** — The `@Published` vars are bound directly in 40+ View call sites. Moving them to a coordinator class would require updating every binding. The extension file approach achieves the same navigability benefit without that risk.
- **DataExportArchiveBuilder further split** — No clean seam; manifest/path-filter helpers are too interleaved.
- **Further RadixStore Private Utilities splits** — The ~428-line tail consists of helpers called from multiple extension files. Extracting them would create circular dependency problems or require duplicating logic.

---

## Android-readiness notes

The portable SQLite logic in `PhraseRepository`, `ComponentRepository`, and their helper files is cleanly separated from iOS/SwiftUI. Platform-specific code is now concentrated in:
- `RadixStoreAI.swift` — `performMacPasteShortcut()` (macCatalyst only, clearly marked `#if targetEnvironment(macCatalyst)`)
- `RadixStoreNavigation.swift` — `UIDevice`, `UIApplication`, `UIPasteboard` calls
- `RadixStore.swift` Core Lifecycle — `#if targetEnvironment(macCatalyst)` guards

For an Android port, the repositories and data models can be reused as Kotlin/portable logic. The ViewModel layer would be reimplemented in Kotlin with the same extension-file domain structure.

---

## Batch history

| Batch | Files created | RadixStore lines after |
|---|---|---|
| Start | — | 4,204 |
| 1 | `PhraseQueryRunner.swift` | — (Services layer) |
| 2 | `RadixStoreCollections.swift` | 4,032 |
| 3 | `RadixStorePrompts.swift` | 3,877 |
| 4 | `RadixStoreFavorites.swift` | 3,799 |
| 5 | `RadixStoreDataEdit.swift`, `RadixStorePhraseFile.swift` | 3,237 |
| 6 | `RadixStoreSearch.swift`, `RadixStoreNavigation.swift`, `RadixStoreImagePhrase.swift` | 2,062 |
| 7 | `RadixStoreRootsBreadcrumb.swift`, `RadixStoreRootsCache.swift` | 1,732 |
| 8 | `RadixStoreDataEditHelpers.swift`, `RadixStoreAI.swift`, `RadixStoreGrid.swift` | **1,078** |
