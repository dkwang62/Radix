# Android Migration Prep

This codebase is still a native SwiftUI app, but Android migration should start from
portable domain behavior rather than screens.

## Portable Contracts Added

- `RadixSearchQuery` in `Models/PinyinSearchNormalizer.swift`
  - Trims raw search input.
  - Supports forced English search with `=term`.
  - Supports forced English search with straight or curly quotes.
  - Exposes `rawText`, `effectiveText`, `isForcedEnglish`, and `isEmpty`.

- `RadixTextClassifier` and `PinyinSearchNormalizer.normalizedCompactQuery`
  - Identify likely pinyin queries.
  - Identify Chinese character text.
  - Normalize pinyin-like text for searching and sorting.

- `PhraseLengthRule` in `Models/PhraseModels.swift`
  - Owns phrase length filter options.
  - Defines the `7+` overflow bucket.
  - Provides labels, cache keys, lookup lengths, and phrase match checks.

- `PhraseResultRules` in `Models/PhraseModels.swift`
  - Sorts phrase results by normalized pinyin, original pinyin, then word.
  - Merges primary and secondary phrase results by unique word.

- `AddedPhraseReviewFilter` in `Models/PhraseModels.swift`
  - Defines the review filter buckets used by the added-phrase review workflow.
  - Maps filters to review tools/statuses without SwiftUI dependencies.
  - Leaves icon/color styling in the SwiftUI layer.

These rules should be mirrored exactly in Kotlin before porting UI behavior.

## Recommended Migration Order

1. Port pure models and value rules.
   - `PhraseItem`
   - `PhraseReviewStatus`
   - `AddedPhraseReviewFilter`
   - `PhraseLengthRule`
   - `PhraseResultRules`
   - `RadixSearchQuery`
   - `RadixTextClassifier`
   - `PinyinSearchNormalizer`

2. Port repository/query services.
   - Component search
   - Phrase lookup
   - Pinyin search normalization
   - Backup package encoding/decoding

3. Port state orchestration.
   - Keep Android ViewModels thin.
   - Avoid copying SwiftUI layout concerns into Kotlin domain code.

4. Port UI last.
   - Compose screens should call the same domain contracts.
   - Any behavior that affects search, phrase filtering, backup contents, or review state should live outside composables.

## Current Boundary Rule

If a function can be tested without `SwiftUI`, `UIKit`, `AppKit`, file pickers,
camera, speech, or StoreKit, it should live in `Models` or `Services`, not in a
SwiftUI view or `RadixStore` view-state method.
