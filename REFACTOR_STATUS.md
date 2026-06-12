# Radix maintainability refactor — completed status

**Build status: CLEAN (desktop layout platform boundary split)**
Last verified build: `xcodebuild -project Radix.xcodeproj -scheme Radix -destination generic/platform=iOS CODE_SIGNING_ALLOWED=NO build`

---

## Deferred post-review UX direction

Do not include the following changes in the current Apple Review build `1.0.0 (2)`.
That submission should complete with the current implementation.

When starting the next beta, UX refactor, or navigation cleanup, prioritize this direction:

- Treat **Take Photo** as a primary action, not as a full tab destination.
- Add a large, obvious **Take Photo** button to the main Radix iPhone UI.
- Keep this iPhone-first; do not force the same behavior onto iPad or Mac without a separate design pass.
- Tapping **Take Photo** should open the existing camera capture flow.
- After OCR/page creation, route the user to **Browse** with the newly created page selected.
- Move existing image/file import affordances into **Browse** rather than making them global primary actions.
- Eventually remove or hide the Scan tab from primary navigation once the new Take Photo entry point is proven.
- Keep the existing Photos/Files/Safari/Chrome share extension behavior as a secondary import path.

Guardrails for future Codex work:

- Do not redesign features while Apple Review for `1.0.0 (2)` is pending.
- Do not change bundle IDs, signing, App Groups, or TestFlight/App Store settings for this UX refactor.
- Implement the next beta behind a normal build increment, such as `1.0.0 (3)` or `1.0.1`.
- Preserve the current review baseline unless the user explicitly asks to replace the submitted build.

---

## Post-checkpoint update

Desktop layout sizing now uses the platform facade in another app/view cluster:

- Browse saved-page picker heights now use `RadixPlatform.isDesktop` instead of local Catalyst compile branches
- Favorites/study grid columns, phrase row sizing, summary columns, and recent character tile sizing now use `RadixPlatform.isDesktop`
- This reduces app-level `targetEnvironment(macCatalyst)` spread while preserving the same desktop/iOS sizing choices

The iOS build was verified clean with signing disabled after this desktop layout platform boundary pass.

Mac runtime detection now goes through the platform facade:

- `RadixPlatform.isRunningOnMac` owns the `targetEnvironment(macCatalyst)` / `ProcessInfo.processInfo.isiOSAppOnMac` check
- Browse, Smart Search, Components Explorer, phrase lookup, and phrase table views now use the shared platform facade instead of repeating Apple runtime detection
- `ProcessInfo.processInfo.isiOSAppOnMac` now appears only inside `RadixPlatform.swift`

The iOS build was verified clean with signing disabled after this Mac runtime platform boundary pass.

Interaction hint preferences now go through the shared preferences boundary:

- `RadixInteractionPreferences.swift` owns the one-time interaction hint animation preference key
- `InteractionHintRow.swift` keeps local SwiftUI state for immediate animation flow while persistence is handled by the preference boundary
- The app/view/model/service Swift scan no longer reports any remaining `@AppStorage` usage

The iOS build was verified clean with signing disabled after this interaction preferences boundary pass.

Phrase detail preferences now go through the shared preferences boundary:

- `RadixPhrasePreferences.swift` owns the phrase animation script preference key
- `PhraseInfoCard.swift` keeps local SwiftUI state for immediate script-toggle updates, initialized from service-backed preferences
- Phrase animation and control extensions continue to read the card-local script state while persistence is handled by the preference boundary
- The phrase animation preference key no longer appears in view-level `@AppStorage`

The iOS build was verified clean with signing disabled after this phrase preferences boundary pass.

Root UI preferences now go through the shared preferences boundary:

- `RadixRootPreferences.swift` owns the welcome-sheet and sidebar-navigation hint preference keys
- `RootView.swift` keeps local SwiftUI state for immediate presentation updates, initialized from service-backed preferences
- `RootSidebar.swift` continues to toggle local navigation-hint state while persistence is handled by the root preference boundary
- The root preference keys no longer appear in app-level `@AppStorage`

The iOS build was verified clean with signing disabled after this root preferences boundary pass.

Study UI preferences now go through the shared preferences boundary:

- `RadixStudyPreferences.swift` owns the study script, grid scope, saved-page sort-order, and intro-dismissal preference keys
- `FavouritesTab.swift` keeps local SwiftUI state for immediate UI updates, initialized from service-backed preferences
- Study section controls still bind to the same local state while persistence is handled through the preference boundary
- The study preference keys no longer appear in app-level `@AppStorage`

The iOS build was verified clean with signing disabled after this study preferences boundary pass.

Browse UI preferences now go through the shared preferences boundary:

- `RadixBrowsePreferences.swift` owns the browse interaction hint, image script mode, and saved-page sort-order preference keys
- `FilterGridTab.swift` keeps local SwiftUI state for immediate UI updates, initialized from the service-backed preferences
- `BrowseSourcePicker.swift` writes sort-order changes through the browse preferences boundary
- `BrowseScrollRestoration.swift` records the interaction hint as shown through the same service

The iOS build was verified clean with signing disabled after this browse preferences boundary pass.

Local memory snapshots now have a retention guard:

- `LocalDataSnapshotStore.maximumSnapshotCount` caps dated local memory copies at 20
- `LocalDataSnapshotStore.save(_:)` prunes older snapshots immediately after saving a new one
- The cap applies to both My Data “Save Dated Copy” and quick-save memory because both paths use the same snapshot store

The iOS build was verified clean with signing disabled after this local snapshot retention pass.

Other-device backup metadata persistence now goes through the shared preferences boundary:

- `RadixBackupMetadata.swift` owns the `dataEditLastOtherDeviceBackupPath` and `dataEditLastOtherDeviceBackupDate` preference keys
- `RadixPreferences.swift` now exposes double reads for service-owned timestamp preferences
- `RootView.swift` no longer carries duplicated backup metadata `@AppStorage` state
- `DataEditTab.swift` and `DataEditOtherDevicesSection.swift` use local metadata state backed by `RadixBackupMetadataStore`

The iOS build was verified clean with signing disabled after this backup metadata preferences boundary pass.

Capture/manual page quota persistence now goes through the shared preferences boundary:

- `RadixCaptureUsage.swift` owns the `radixFreeCameraScanCount` preference key and clamped increment behavior
- `RadixPreferences.swift` now exposes integer reads for service-owned preference counters
- `CaptureTab.swift`, `FilterGridTab.swift`, and `BrowseCollectionEditing.swift` use `RadixCaptureUsage` instead of direct `@AppStorage` for the free-page counter
- The capture and browse UI still keep local SwiftUI state for immediate screen refresh while persistence is service-owned

The iOS build was verified clean with signing disabled after this capture usage preferences boundary pass.

Capture image file import is now behind a service adapter:

- `CaptureFileImportModifier.swift` owns the image `fileImporter` modifier and selected-file-to-`CapturedImage` loading
- `CaptureTab.swift` now delegates file import presentation to the modifier and reacts through neutral image/error callbacks
- App-layer `fileImporter` / `fileExporter` modifiers are no longer present; remaining transfer modifiers live in `Services`
- Capture recognition continues to receive `CapturedImage` from camera, photo library, and file import paths

The iOS build was verified clean with signing disabled after this capture file import boundary pass.

My Data import/export UI plumbing has been moved behind a service adapter:

- `DataEditTransferModifier.swift` owns the reusable `fileExporter` / `fileImporter` modifiers for My Data exports and backup restores
- `DataEditTab.swift` now delegates transfer presentation to the modifier while keeping export success, restore mode, and alert decisions in the data-edit workflow
- `RadixFileType` aliases the platform file type in `RadixFileTypes.swift`, keeping app state from naming `UTType` directly
- App-level file transfer surface is smaller; the remaining direct app file importer is the capture image file picker

The iOS build was verified clean with signing disabled after this data edit transfer boundary pass.

Photo-library import is now behind a service-owned adapter:

- `CapturePhotoImportButton.swift` owns `PhotosPicker`, `PhotosPickerItem` state, and photo-to-`CapturedImage` loading
- `CaptureHeaderView` now receives neutral album image/error callbacks instead of binding to `PhotosPickerItem`
- `CaptureTab.swift` no longer imports `PhotosUI` or owns selected-photo state; camera, photo, and file paths all enter recognition as `CapturedImage`
- Remaining `PhotosUI` usage is contained in `Services/CapturePhotoImportButton.swift` and the existing image loader overload in `CaptureImageIO.swift`

The iOS build was verified clean with signing disabled after this photo import boundary pass.

File type constants have been centralized behind a service boundary:

- `RadixFileTypes.swift` now owns shared `UTType` values for JSON, data, image import, backup import, and GIF export identifiers
- `CaptureTab.swift` no longer imports `UniformTypeIdentifiers` for image file import
- `DataEditTab.swift` and related export sections now use `RadixFileTypes` instead of direct `.json` / `.data` file type constants
- `FileTransferModifier.swift` and `HanziWriterGIFExporter.swift` now route shared file type choices through the same adapter
- App-layer `UniformTypeIdentifiers` imports are now gone; remaining `UTType` usage is contained in service/document boundaries

The iOS build was verified clean with signing disabled after this file type boundary pass.

File transfer UI plumbing has been moved behind a reusable service adapter:

- `FileTransferModifier.swift` moved from `App` to `Services`
- `RootView.swift` now delegates profile/add-phrases import/export modifiers and transfer alerts to `FileTransferModifier`
- `RootView.swift` no longer imports `UniformTypeIdentifiers` or owns its own security-scoped file read helper
- Xcode project wiring now places the transfer modifier in the service group

The iOS build was verified clean with signing disabled after this file transfer modifier pass.

File document adapters have been tightened into the service layer:

- `AddPhrasesFileDocument.swift` moved from `App` to `Services`, alongside `BinaryFileDocument` and `JSONFileDocument`
- `RadixStore.swift` no longer imports `UniformTypeIdentifiers` unnecessarily
- Remaining UTType references are now limited to real file importer/exporter UI and document service boundaries

The iOS build was verified clean with signing disabled after this file document adapter pass.

StoreKit product types no longer leak into paywall views:

- `RadixStoreProduct` wraps StoreKit `Product` display fields and keeps the purchase handle service-private
- `EntitlementManager.products` now exposes `[RadixStoreProduct]`, and `purchase(_:)` accepts the wrapper
- `PaywallView.swift` and `PaywallPlans.swift` no longer import StoreKit or reference `Product` directly
- StoreKit remains contained inside `EntitlementManager` with non-StoreKit fallback behavior

The iOS build was verified clean with signing disabled after this StoreKit product boundary pass.

Optional Apple framework services now compile behind availability gates:

- `CaptureImageIO.swift` keeps generic image byte/file loading independent from PhotosUI; the `PhotosPickerItem` overload is compiled only when PhotosUI is available
- `CharacterSpeechService.swift` keeps the AVFoundation speech implementation under `canImport(AVFoundation)` and provides a no-op fallback with the same public API otherwise
- This reduces hard Apple framework dependencies in service files while preserving current iOS behavior

The iOS build was verified clean with signing disabled after this optional-framework service boundary pass.

GIF export now fails cleanly when platform rendering is unavailable:

- `HanziWriterGIFExporter.swift` no longer uses `fatalError` for non-UIKit rendering paths
- Frame rendering now throws a normal Radix export error when GIF frame creation is unavailable or image extraction fails
- The exporter keeps its iOS rendering implementation unchanged while exposing safer behavior for future non-Apple targets

The iOS build was verified clean with signing disabled after this GIF export error-boundary pass.

Platform UI adapters now compile behind explicit availability gates:

- `CameraCaptureView.swift` keeps the iOS `UIImagePickerController` implementation under `canImport(UIKit)` and provides a fallback SwiftUI view when camera capture is unavailable
- `StrokeOrderWebView.swift` keeps the WebKit/`UIViewRepresentable` implementation under `canImport(UIKit) && canImport(WebKit)` and provides a fallback stroke character view otherwise
- These adapters remain service-owned while exposing stable SwiftUI view names to the app workflow layer

The iOS build was verified clean with signing disabled after this conditional adapter pass.

Apple dynamic SwiftUI colors have been moved behind a theme boundary:

- `RadixTheme.swift` now owns platform dynamic colors such as background, secondary/tertiary background, grouped background, separator, and system gray
- `App`, `Views`, and existing service UI adapters now use `RadixTheme` instead of direct `Color(.systemBackground)` / `Color(.separator)` style calls
- The native color surface is now centralized for later Android theme mapping

The iOS build was verified clean with signing disabled after this theme boundary pass.

Camera capture presentation has been moved out of the app workflow layer:

- `CameraCaptureView.swift` now lives under `Services` as the iOS `UIImagePickerController` adapter
- `CaptureTab.swift` still owns the capture workflow and receives neutral `CapturedImage` values
- Xcode project wiring now places the camera picker bridge in the service group

The iOS build was verified clean with signing disabled after this camera picker adapter boundary pass.

Stroke-order WebKit rendering has been separated from its SwiftUI section:

- `StrokeOrderWebView.swift` now lives under `Services` as the platform WebKit adapter
- `StrokeOrderSection.swift` remains under `Views` with the visible section, stable reload token helper, and animation header label
- Xcode project wiring now places the WebKit bridge in the service group and compiles the new view companion file

The iOS build was verified clean with signing disabled after this stroke-order adapter boundary pass.

Animation GIF export/parsing has been moved out of the view layer:

- `HanziWriterGIFExporter.swift` and `HanziSVGPathParser.swift` now live under `Services`
- `CharacterAnimationSharing.swift` still coordinates the user action, while export/render/parse work is service-owned
- Xcode project wiring now places both animation export helpers in the service group

The iOS build was verified clean with signing disabled after this GIF export boundary pass.

Active capture preview rendering now goes through the captured-image boundary:

- `CapturedImage.swift` — exposes a SwiftUI `preview` image while keeping platform image construction inside the wrapper
- `CaptureWorkbenchViews.swift` — no longer imports UIKit or calls `Image(uiImage:)` directly for the active capture preview

The iOS build was verified clean with signing disabled after this capture-preview boundary pass.

Share-sheet presentation has been moved out of the view layer:

- `RadixSharePresenter.swift` — new service-layer platform presenter for iOS `UIActivityViewController` and macOS sharing
- `CharacterAnimationSharePresenter.swift` — removed from `Views`; animation sharing still calls `presentShareSheet(items:)` through the new service boundary
- Xcode project wiring now places the presenter in `Services`

The iOS build was verified clean with signing disabled after this share-presenter boundary pass.

Camera capture now feeds the neutral capture-image boundary directly:

- `CameraCaptureView.swift` — still owns the iOS `UIImagePickerController`, but now converts the picked image to `CapturedImage` before calling back into app state
- `CaptureTab.swift` — camera, photo picker, and file import recognition paths now all receive `CapturedImage`
- `CaptureImageIO.swift` — removed the raw `UIImage` conversion helper from the shared loader API
- Stale UIKit/AppKit imports were removed from several SwiftUI-only files, including breadcrumb, My Data, changed-dictionary, root phone, and character context-menu views

The iOS build was verified clean with signing disabled after this camera boundary pass.

Saved-page thumbnail rendering has been moved behind a small cross-platform image boundary:

- `RadixThumbnail.swift` — wraps saved thumbnail JPEG data and owns platform-specific SwiftUI image construction
- `RadixThumbnailView` — reusable thumbnail/placeholder renderer for saved page rows
- Browse source rows, Favorites page rows, backup preview rows, and Capture saved-page rows now pass `RadixThumbnail` instead of decoding `UIImage` directly
- UIKit imports were removed from the thumbnail-only row/list files

The iOS build was verified clean with signing disabled after this thumbnail boundary pass.

`RadixStore` preference persistence has been moved behind `RadixPreferences` for Android migration:

- `RadixPreferences.swift` — now supports array and dictionary reads in addition to data/string/bool/object access
- `RadixStore.swift` — sidebar style, speech settings, search history, preview restoration, profile restore, and AI prompt settings now use the shared preferences wrapper
- `RadixStoreSearch.swift`, `RadixStoreCollections.swift`, `RadixStoreFavorites.swift`, `RadixStoreDataEdit.swift`, and `RadixStoreRootsBreadcrumb.swift` — split store extensions now persist through `RadixStore.preferences`

The iOS build was verified clean with signing disabled after this store-preferences migration.

Remaining direct device-class layout checks in the main App/View layer have been moved to `RadixPlatform`:

- Phone/tablet UI branches in Browse, Smart Search, Favorites, My Data, phrase tables, character preview/header cards, component popovers, and popover sizing now use `RadixPlatform.isPhone` or `RadixPlatform.interfaceIdiom`
- The only remaining direct `UIDevice`, `UIPasteboard`, and `UIApplication.open` references in the scanned app surface are inside `RadixPlatform.swift`

The iOS build was verified clean with signing disabled after this platform-layout pass.

Preferences and platform actions have been further isolated for Android migration:

- `RadixPreferences.swift` — shared key-value preference wrapper around `UserDefaults`, intended to map to Android shared preferences or DataStore later
- `PhraseAddDatabaseLocationManager.swift` — custom added-phrases DB path/bookmark persistence now uses `RadixPreferences`
- `EntitlementManager.swift` — persisted entitlement/debug flags now use `RadixPreferences`; StoreKit remains the iOS purchase bridge
- `RadixPlatform.swift` — now centralizes pasteboard reads/writes and external URL opening
- `AILinkPromptOutput.swift`, `CharacterAnimationSharing.swift`, `BrowseCollectionEditing.swift`, and `BrowseImageActions.swift` — now route clipboard/open behavior through `RadixPlatform`

The iOS build was verified clean with signing disabled after this preferences/platform-actions pass.

Capture image/OCR handling has been split for Android migration:

- `CapturedImage.swift` — neutral captured-image wrapper carrying image bytes and orientation, with an iOS preview image only behind `canImport(UIKit)`
- `CaptureImageIO.swift` — image loading from Photos/files/camera and thumbnail generation
- `CaptureOCRService.swift` — OCR now recognizes text from `CapturedImage` data/orientation instead of raw `UIImage`
- `CaptureTab.swift` — capture flow now stores `CapturedImage`, uses `RadixPlatform` for phone behavior, and no longer imports UIKit directly

The iOS build was verified clean with signing disabled after this capture boundary split.

`RadixPlatform.swift` has been added as the platform facade for Android migration work:

- `RadixPlatform.swift` — device class, clipboard writes, and external URL opening
- `RadixStoreNavigation.swift` — now uses platform intent (`isPhone`, `open`, `copyToPasteboard`) instead of direct `UIDevice`/`UIApplication`/`UIPasteboard` calls
- `RadixStoreRootsBreadcrumb.swift` — browse-memory highlight mode now depends on `RadixPlatform.isPhone`
- `RadixStore.swift` — lineage batch sizing now depends on `RadixPlatform.isDesktop`
- `BrowseGridLayout.swift` and `ResponsiveFont.swift` — model/layout helpers now consume the shared platform facade instead of asking UIKit directly

The iOS build was verified clean with signing disabled after this Android-readiness pass.

`AddedPhraseReviewSheet.swift` has now been split into focused added-phrase review files:

- `AddedPhraseReviewSheet.swift` — review state, filtered data, status mutations, paging/delete actions
- `AddedPhraseReviewControls.swift` — filter picker, status tool row, search field, page controls
- `AddedPhraseReviewDetail.swift` — selected phrase detail card and empty-state copy
- `AddedPhraseReviewGrid.swift` — paged phrase grid and reusable review tile
- `AddedPhraseReviewFilter.swift` — review filter enum, status inclusion, and tool mapping

The duplicated Gemini request validation, URL construction, HTTP handling, and user-facing API error messages have also been extracted into `GeminiClient.swift`. `RadixStoreAI.swift` now only coordinates store-level AI actions and URL/paste helpers.

The iOS build was verified clean with signing disabled after this cleanup. A normal signed build still depends on local provisioning for `com.desmond.radix`.

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
| `RadixStoreAI.swift` | 174 | Store-level Gemini action orchestration, AI URL construction, Mac clipboard paste |
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

**Gemini support** split:
- `GeminiClient.swift` (236 lines) — shared Gemini request validation, HTTP transport, error mapping, phrase extraction, and text generation services
- `RadixStoreAI.swift` (174 lines) — store-level orchestration, AI URLs, and Mac clipboard paste

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
- `RadixPlatform.swift` — current interface idiom, clipboard writes, and external URL opening
- `RadixPreferences.swift` — persisted app flags and service settings backed by `UserDefaults` on iOS
- `CapturedImage.swift` / `CaptureImageIO.swift` / `CaptureOCRService.swift` — platform image loading, thumbnail generation, and OCR bridge
- `RadixStoreAI.swift` — `performMacPasteShortcut()` (macCatalyst only, clearly marked `#if targetEnvironment(macCatalyst)`)
- `RadixStore.swift` Core Lifecycle — remaining lifecycle `#if targetEnvironment(macCatalyst)` guard

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
