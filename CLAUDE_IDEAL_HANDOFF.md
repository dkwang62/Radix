# Claude Ideal Handoff

Last updated: 2026-07-06

This handoff summarizes the current progress toward the UI polish target that was
called the "Claude ideal": shared radii, shared accent usage, haptics, reusable
surface primitives, type/icon consistency, explicit sheet sizing, and stable
navigation structure.

## Overall Estimate

Rough completion: 86%.

The foundation is in place and many simple surfaces have been converted. The
remaining work is mainly an audit and surgical cleanup pass. Avoid broad
mechanical replacements in complex SwiftUI views; earlier broad surface/grid
rewrites caused `EXC_BAD_ACCESS` crashes in SwiftUI composition even when builds
and tests passed.

## Current State By Goal

| Goal | Estimate | Current state | Remaining work |
| --- | ---: | --- | --- |
| Corner radius drift | 95% | Shared radius tokens exist in `Services/RadixTheme.swift`; current polish has converged on small card radii and modal radii. | Audit new/local `cornerRadius` uses only when touching nearby code. Do not churn stable leaf views just to rename constants. |
| Default system accent | 78% | `RadixAccent.primary` aliases the asset-catalog accent. Recent commits converted shared chevron rows, Add Phrase headers, Character Studio headers, root action tiles, source controls, My Data backup surfaces, and root sidebar affordances. | Continue converting direct `Color.accentColor` where it is brand-primary tinting. Leave semantic status colors alone unless intentionally reclassified. |
| Haptics | 72% | Shared haptics are wired into focused mutation moments: adding phrases, importing pasted AI phrases, removing an added phrase from review, saving phrase notes, and saving/reverting/deleting edited characters. | Audit remaining destructive/confirmation flows such as backup restore/replace, Study checkpoint restore, bulk review actions, imports, and major quiz completion moments. |
| Hand-rolled cards/surfaces | 82% | `radixCard`, `radixPill`, `radixSurface`, and `radixIconButtonSurface` are established and adopted across many simple leaf surfaces. Many fixed small grids were converted to explicit rows/stacks. | Prefer helper adoption in simple views. For AI Link, info cards, phrase review, Browse grids, Conversation Practice, Paywall, and Favorites, make surgical changes only and verify by running the app. |
| Font sizes/icons | 84% | `RadixTypeScale` and `RadixIconSize` exist; icon surfaces are increasingly consolidated through `radixIconButtonSurface`. | Continue moving local icon backgrounds and ad hoc small controls onto shared helpers when touching the owning surface. Avoid changing text hierarchy without visual review. |
| Sheet sizing | 80% | Root-level and Browse editing/report sheets declare detents. The Added Phrase Review crash was stabilized by using explicit framing/page sizes and no geometry feedback loop. | There are still many `.sheet` call sites. Audit each for explicit detents only where the content needs predictable height; some phone detail sheets may intentionally rely on defaults or helper modifiers. |
| Navigation structure | 90% | Navigation was reviewed and largely left as-is. Catalyst now enters the iPad split shell directly and avoids root-level `NavigationSplitView` titles/principal toolbar items that triggered title-merge crashes. | Preserve the current Browse/Study/AI/My Data model. Continue only targeted return-path and title/header fixes; do not reorganize the tab structure as part of visual cleanup. |

## Recent Completed Units

- `aa85d76` - Root sidebar active tabs and checkpoint affordances now use `RadixAccent.primary`.
- `0399b3b` - Capture source controls and Browse source-menu selection affordances use `RadixAccent.primary`.
- `8f56968` - My Data backup surfaces use `RadixAccent.primary` for brand tint while destructive replacement remains orange.
- `1cc3e63` - Shared controls, Add Phrase headers, Character Studio headers, root action tiles, script controls, welcome steps, and navigation guide icons use `RadixAccent.primary`.
- `be34198` - Haptics wired into key edit/import/save/delete mutation moments.
- Earlier polish commits also deduplicated several descriptor-driven rows, converted multiple fixed small grids to explicit rows/stacks, reused shared Add Phrase/Character Detail surfaces, and stabilized Added Phrase Review after crash reports.

## Important Crash Lessons

The previous crashes did not reverse the goal. They narrowed the implementation
strategy.

- `RootView` / Catalyst split crash: avoid `.navigationTitle` and principal title
  toolbar items inside Catalyst `NavigationSplitView` columns. In-content headers
  own workspace identity.
- `PhraseInfoCard`: keep sentence and ordinary phrase content in separate
  top-level stacks. Keep animation tiles as explicit rows, not lazy grids.
- `AddedPhraseReviewSheet`: keep the review surface and phrase grid directly
  framed with fixed platform page sizes. Avoid geometry-driven adaptive paging
  that feeds measurements back into the view tree.
- Complex SwiftUI surfaces should not receive broad automatic replacement of
  background, clip shape, overlay, and lazy grid structure in one pass.

## Suggested Next Work For Claude

1. Run `rg -n "Color\\.accentColor" App Views Services Models ViewModels`.
2. Classify each hit as one of:
   - brand-primary tint: convert to `RadixAccent.primary`;
   - semantic status color: leave direct or introduce a semantic alias;
   - focus/selection system behavior: leave unless visual intent is clear.
3. Good low-risk accent candidates include simple headers, help icons, paywall
   brand highlights, settings/glossary icons, and compact leaf controls.
4. Higher-risk candidates include Browse grids, Smart Search grids, Phrase
   summary tiles, Added Phrase Review status colors, Conversation Practice quiz
   state, and AI Link output. Change those only with screenshots/runtime checks.
5. Audit `.sheet(` call sites against `presentationDetents`. Add detents where
   content height is part of the workflow; do not force detents onto sheets that
   intentionally inherit platform defaults.
6. Continue helper adoption opportunistically:
   - compact icon backgrounds -> `radixIconButtonSurface`;
   - rounded chips -> `radixPill`;
   - simple cards -> `radixCard`;
   - plain rounded backgrounds/borders -> `radixSurface`.
7. After each focused unit, update `PROJECT_CONTEXT.md`, run verification, and
   commit separately.

## Verification Expected For Each Unit

Run the repository verification from `PROJECT_CONTEXT.md`:

1. `git diff --check`
2. `swift test`
3. `xcodebuild -quiet -project Radix.xcodeproj -scheme Radix -destination 'generic/platform=iOS Simulator' build`
4. `xcodebuild -project Radix.xcodeproj -scheme Radix -destination 'platform=macOS,variant=Mac Catalyst' CODE_SIGNING_ALLOWED=NO build`

For any UI surface that previously crashed or is listed as high risk above, also
launch the app and exercise that screen on iPhone and Catalyst.

## Dirty Worktree Warning

At the time this handoff was written, these files were already dirty and were not
part of the UI polish commits:

- `Resources/Localizable.xcstrings`
- `phrases_add.db`

Do not include them in a polish commit unless the change is intentional.
