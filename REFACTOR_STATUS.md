# Radix maintainability refactor — completed status

**Build status: CLEAN (batch 8 fix5)**
Last verified build: `xcodebuild -project Radix.xcodeproj -scheme Radix -destination generic/platform=iOS build`

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
