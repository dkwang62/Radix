# Radix Project Context

This is the concise engineering hand-off and current source of truth for ongoing
Radix work. Read it before changing the project. Update it in the same commit as
each completed work unit. Git remains the detailed historical record; this file
describes the present state and immediate direction.
`CODEX-HANDOFF3.md` is the current quick restart summary for future Codex
sessions and should stay aligned with this file when the workstream meaningfully
changes. Earlier handoff files remain historical snapshots.

Last reviewed: 2026-07-30

Current app version metadata is marketing version `1.0.4`, build `21`.
Settings > About shows the bundle version and build so future release bumps are
visible in the app.

`UI_INTENT.md` now includes the durable Radix UI preference guide. Future UI
work should follow that guide before adding controls, screens, navigation paths,
or parallel component implementations.
Build 16 is preserved at git tag `radix-build-16-before-title-navigation`
before the title-dropdown navigation experiment.
Root title dropdowns own visible primary screen titles. Child views such as AI
Link and Settings should not add a second static `navigationTitle` when shown
inside the root navigation shell; modal sheets may still own their focused
sheet titles.
Camera/Capture is the owner for page creation sources. It should open Camera
directly when launched from the global Camera action, then expose Camera, Album,
Files, Clipboard Image, and Text to Page source buttons after the camera sheet is
dismissed. Browse may still offer page-source shortcuts, but page creation
sources must not exist only in a hidden Browse panel.
Image workflows use Apple Vision first for speed. If Vision returns no readable
Chinese or errors, Radix may fall back to Gemini image OCR with the source image
and then create the page from the AI-read text through the same saved-page flow.
Original OCR is a page action, not a visible page artifact button. Keep it in
the saved-page `Actions` menu so source inspection remains available without
crowding Study or Browse artifact rows.

## Version 1.1 Direction

The pre-1.1 app is preserved at git tag `radix-v1.0-before-v1.1`.
Version 1.1 work follows `VERSION_1_1_PLAN.md`: Radix should become a linked
Page -> Sentence -> Phrase -> Character learning graph. Browse remains the
source-inspection home for Original OCR, while Study becomes the page-centered
learning workspace for extracted sentence pages, sentence study, phrases,
translation, quiz, conversation practice, and notes.
Extracted sentence pages are modeled as page-owned `AICleanedPageRecord` artifacts, not
as replacements for `CharacterCollection.originalOCRText` or corrected OCR
pages. The saved-page AI task `task12` / `Extract Sentences` generates
JSON for that record from the selected page's characters and OCR/source context,
including per-sentence Chinese, pinyin, English, and phrase hints.
Extracted sentence page records are stored in `RadixStudyPreferences.aiCleanedPages`,
included in the separate sentence transfer surfaces,
imported from fenced or raw AI JSON through AI Link, and removed with their
owning saved page.
Saved pages are user-facing Browse content, not a separate top-level `Pages`
destination. Browse page pickers and Browse title-menu page entries open the
selected page's tile reader directly, and the selected Browse page toolbar
exposes a compact `Study` action for page learning. Browse and the internal
saved-page Study workspace share the same `Actions` menu vocabulary for page
editing, OCR/source review, phrase selection, translation, AI tasks, and
delete; do not reintroduce separate Browse-only or Study-only page action rows.
The existing saved-page Study implementation remains the internal page-learning
workspace and may be opened from explicit Study/page actions, including My Data
inventory links. The Study title menu exposes this route as `Study Pages`; it
must not be promoted back into a top-level `Pages` destination.
Successful Capture, share-extension, and Browse page-creation flows should also
open their newly created page in Browse immediately. Page AI tasks run from the
shared saved-page action menu and should not move the user away from Browse just
because an artifact was created. Browse continues to own dictionary/source
inspection, with OCR pages labeled as Original OCR or Corrected OCR when the
user opens a page source. The Browse page toolbar should not show a permanent
character-count pill; the title and tiles already establish the selected page.
Saved-page AI action labels, icons, visibility, and task IDs are centralized in
`CollectionPageAITaskKind` near `CollectionPageActionsMenu`. Browse and Study
may keep different success navigation/status handling, but they should not
define separate page AI task arrays or manual fallback task-id switches.
The extracted-sentences reader uses the shared Study simplified/traditional display choice;
the switch converts the visible cleaned title, page text, notes, sentence
rows, and opened sentence card display without changing the stored record.
Keep the extracted-sentences reader, paging/cache helpers, fallback sentence
record construction, and its focused `Back to Study` button in
`FavouritesAICleanedPage.swift` rather than growing `FavouritesSections.swift`.
The `Extract Sentences` prompt is a whole-page conversion task: the AI must
process the entire source/OCR text into cleaned prose and sentence records in
reading order, not choose a representative subset of study sentences. It should
expand abbreviations, telegraphic headline style, and compressed journalistic
compound wording into ordinary Chinese phrases or clauses suitable for sentence
study while preserving the source meaning. It should also filter pure OCR noise,
duplicated lines, unrepairable nonsense, and isolated fragments that cannot
become coherent sentences without inventing facts; the output sentence array
should contain distinct, fully formed, grammatically correct sentences.
The importer remains tolerant at the boundary: exact Radix JSON is preferred,
but common AI variants such as camelCase keys, nested page/result/data objects,
cleaned-page wrapper keys, `zh`/`en` sentence fields, string phrase lists,
prose-only output, prose-wrapped top-level sentence arrays, and numbered
Chinese sentence lists should be salvaged into `AICleanedPageRecord` when
possible.
Sentence previews still use the shared `PhraseInfoCard` presentation route, and
sentence mode must stay rich enough for learning: whole sentence, English
meaning, optional pinyin, read aloud, Phrase button, four-character stroke
animation pages, favorite, sentence-level AI context-menu actions, and delete.
The sentence-card AI context actions use sentence-subject templates: `Explain
with AI` uses the built-in `Sentence` template, while `Improve Sentence with AI`
uses `Sentence Improvement`. They copy the selected sentence prompt and open the
selected/default AI provider directly; they should not fall back to a character,
phrase, page, or generic starter template.
AI Link also includes a built-in sentence-subject `Sentence Improvement` task.
It takes an existing sentence or messy input string and must return one JSON
payload containing the improved Chinese sentence, pinyin generated from that
final sentence, and the English meaning of that final sentence. Its `Paste AI
Answer` workflow treats those three fields as one synced update: it replaces
the selected saved sentence text, pinyin, and English meaning in the sentence
database, preserving sources, favorites, and notes while refreshing
character/phrase hints from the improved sentence. When the saved sentence came
from an extracted-page artifact, the same edit must also replace the sentence,
pinyin, and English meaning inside the owning `AICleanedPageRecord`; otherwise
page sentence readers will keep showing stale page-owned data. Older persisted
copies of the built-in `Sentence Improvement` prompt must normalize to the
current JSON contract so users see the updated template without manually
resetting AI settings. Sentence-card `Improve Sentence with AI` should route to
AI Link with the sentence and task selected so the normal prompt, paste, and
apply workflow remains visible; non-importing `Explain with AI` may still use
the quick external AI launch path.
Prompt model data and prompt rendering are split deliberately:
`PromptModels.swift` owns prompt subjects, task defaults, IDs, configuration,
and render context, while `PromptConfigRendering.swift` owns normalization,
legacy task repair, and placeholder substitution.
Custom AI Link tasks carry an explicit subject type. Character/Phrase tasks use
the recent subject chooser, Page tasks use the saved-page chooser, and Sentence
tasks use a searchable saved-sentence chooser that queries only a small visible
slice of the sentence database. Creating a new custom task must reuse an
existing untouched blank custom draft instead of adding another empty task, and
AI Link may clean up duplicate blank custom drafts automatically. Only custom
tasks are deletable; built-in tasks should remain recoverable through defaults.
Keep the crash guardrails: the Phrase
button should show all exact phrase-library matches in the sentence by merging
stored sentence phrase hints with on-demand phrase discovery when the phrase
sheet is opened. The full sheet lookup must use cached batch phrase discovery,
not one SQLite lookup per candidate, and should skip dynamic discovery for
unusually long sentence strings where stored/preprocessed hints are the safe
fallback. Sentence highlighting can still use the non-overlapping
longest-phrase rule. Do not run discovery merely to render a sentence row, open
a sentence card, or decide whether the button is visible. Tapping
stroke-animation tiles inside a sentence should keep the sentence card open
instead of replacing it with a nested character/phrase preview stack on iPhone.
Tapping one records the character in History and may speak it, without opening
another preview layer; their context menu may also offer `Add to History`.
Phrase rows opened from a sentence-scoped Phrase Library must inspect the
phrase inside that sheet on every device; do not send them to the sidebar
character/phrase card route.
The Phrase Library sheet owns one top-left contextual return action. When the
sheet was opened from a sentence, that action is always `Back to Sentence` and
dismisses directly to the originating sentence card, even after inspecting a
phrase inside the sheet. Phrase- and character-origin phrase lookups inspect
selected phrases inside the same sheet with `Back to Phrase` or `Back to
Character`, so they do not replace the underlying sidebar object. Do not
reintroduce a bottom close button or a nested phrase-detail -> phrase-list ->
origin return path. Phrase cards opened from inside a Phrase Library sheet are
also terminal for phrase lookup: they must not show another `Phrase` button,
because phrase -> phrase -> phrase nesting becomes confusing and breaks the
single visible return rule. If a phrase-list callout routes the selected phrase
through the sidebar instead of inside the sheet, it must pass
`PhraseLookupDepth.terminal` so the sidebar card also hides its `Phrase` button.
Top-level phrase previews use `PhraseLookupDepth.topLevel`. This must be driven
by explicit origin state, not inferred from whether stored sentence phrase hints
are available, because sentences without usable hints can fall back to dynamic
lookup. Conversation Practice inspection follows the same boundary: opening the
whole sentence card keeps phrase lookup available, while opening one of that
sentence's phrase hints is terminal and must not expose another phrase lookup.
Saving or restoring an extracted sentence page also upserts its sentence list into the
shared `SentenceExampleRecord` database with `ai_cleaned_page` page-linked
source metadata, so Study > Sentences and sentence cards reuse the same records.
Re-extracting one page replaces that page's output: sentences absent from the
replacement lose only that page's AI-extraction source and are deleted only when
they have no other source and are not favorited.
The live sentence-example store is SQLite-backed via `RadixStudyPreferences`;
Study > Sentences > Transfer owns the fast sentence database `.db` export/import
for Radix-to-Radix moves, including merge and replace modes with safety
snapshots. User-facing Study copy should call these actions `Export Sentences`,
`Import Sentences`, and `Clear Saved Sentences` rather than exposing `DB` or
database terminology. The same Transfer menu owns the explicit clear-sentences
destructive action; it creates a sentence database safety snapshot first and
clears only the saved sentence library, leaving pages, phrases, and practice
sets intact. `sentence_examples` JSON remains in Advanced `Sentence Library
(JSON)` for portable/developer inspection, and legacy UserDefaults payloads are
migrated into the database on first read.
Sentence examples are canonically stored as simplified Chinese, including phrase
and character hints; traditional Chinese is a display mode exposed by sentence
lists, example sheets, and sentence cards, not a second storage form.
Conversation practice model files are split by concern: core pack/import
decoding and general key/text rules remain in `ConversationPracticeModels.swift`,
pack validation lives in `ConversationPracticeValidationModels.swift`, practice
library set/item/membership mapping lives in
`ConversationPracticeLibraryModels.swift`, topic catalog and generation-brief
models live in
`ConversationPracticeTopicModels.swift`, shared sentence-example storage models
live in `SentenceExampleModels.swift`, favorite sentence serialization lives in
`FavoriteSentenceModels.swift`, Radix capture JSON payload/import parsing lives
in `RadixCaptureModels.swift`, progress outcome/item/snapshot/summary types live in
`ConversationPracticeProgressModels.swift`, and character quiz question/choice
rules live in `ConversationPracticeQuizRules.swift`.
Study sentence-style screens, including Study > Sentences, Conversation
Practice, and extracted sentence readers, share the `PracticeSentenceSurface`
toolbar primitives. Keep the page navigation, selection/actions, and
script/language display controls arranged through the shared
`practiceSentenceControlRow`, and keep Chinese/English as one compact toggle
button rather than a fixed-width segmented picker. This row must use
deterministic phone/narrow versus wide layouts, not a measurement-based
multi-candidate layout around interactive menus/buttons, so iPad split layouts
do not hang or compress labels into vertical fragments.
Study > Sentences keeps only page navigation and display/script controls in the
top toolbar. Source filtering, compact sentence search, the minimum Chinese
character-count filter, and one sentence tools menu belong on the lower source
row on every device. The minimum-count slider filters sentences by at least that
many stored Chinese characters; it is not a maximum-length rule. The database
query must compare this threshold as a number, not a text binding, so filtered
page counts and visible rows stay aligned. The tools menu owns
selection, sentence transfer, and a nested `Delete...` submenu so destructive
sentence actions are separated from normal tools. Single-sentence deletes also
require confirmation. Do not keep parallel standalone Select, Delete Results,
or Transfer button helpers for this screen. Keep Study Sentences toolbar/menu
code in `FavouritesSentenceControls.swift`, query/paging data flow in
`FavouritesSentenceData.swift`, sentence row actions/source routing in
`FavouritesSentenceRows.swift`, sentence database transfer actions in
`FavouritesSentenceTransfer.swift`, and single-sentence delete confirmation in
`FavouritesSentenceDeletion.swift`, and sentence editing in
`FavouritesSentenceEdit.swift` rather than growing `FavouritesSections.swift` or
`FavouritesTab.swift`.
Keep Study sheets, file importers/exporters, and confirmation alerts in
`FavouritesPresentations.swift` so `FavouritesTab.swift` can focus on state,
main content, lifecycle, and navigation handling.
Page-linked sentence actions should open the source in `Pages`; Browse is only
for explicit source/OCR inspection from a page's `Browse` action.
Shared language-learning buttons should use meaningful text badges instead of
generic typography icons: `中 Chinese`, `英 English`, and `拼 Pinyin` are clearer
than `Aa`/`textformat` symbols for sentence display and pinyin controls.
Settings exposes the only user-triggered `Optimize Database` maintenance
action. Keep technical cleanup details out of the main UI: the Settings action
may rewrite Radix-owned sentence, extracted-page, added-phrase, and
phrase-favorite storage into Simplified Chinese, but it must not perform a
full sentence-by-phrase relink pass. Stored sentence phrase links are cache
hints, not authoritative truth; phrase adds/deletes/status changes perform
targeted write-time hint updates, and the sentence Phrase button can discover
full matches on demand. Traditional remains display-only. Normal Study
Sentences, practice, phrase-card Examples, sentence-card, and
extracted-sentence reader access must never repair or rediscover phrase links
while rendering; they are read-only consumers of stored hints. Bulk
optimization, sentence phrase-link refresh, storage health, and database
optimization fingerprints live in `RadixStoreDataMaintenance.swift`; Character
Studio edit/import operations remain in `RadixStoreDataEdit.swift`.
restore/import must not start optimization automatically; it should only mark
optimization as recommended until the user explicitly runs Settings >
Optimize Database.
The mutable SQLite stores for Study Sentences and added phrases keep quiet
internal safety snapshots before bulk import/restore, optimization, phrase
cleanup, sentence deletion, and phrase-link maintenance. Settings > Storage
exposes these snapshots under `Recovery Copies` for transparent inspection,
manual safety-copy creation, and explicit restore without turning recovery into
a distracting primary workflow.
Advanced `Full Dataset (JSON)` is schema 2 and includes both the merged coding
foundation (`dictionary` and `phrases`) and a nested lightweight
`portable_backup` payload with the latest saved pages, Conversation practice,
progress, page phrase extractions, profile, and API-key backup metadata. The
heavy Sentence Library is not part of normal backup/restore or Full Dataset;
Study > Sentences exposes fast sentence database transfer for normal use, while
Advanced exposes a separate `Sentence Library (JSON)` export/import for saved
sentences and extracted sentence pages when a portable, inspectable format is
needed. Keep normal backup aligned with `portableBackupPackage()` whenever new
lightweight user-owned data is added.
Settings maintenance actions that scan or rewrite the sentence database must
run as async background work from the UI. Do not call synchronous store paths
directly from SwiftUI buttons, or Mac Catalyst can show the app as not
responding while SQLite and phrase-link maintenance run.
App scene transitions must also remain idle when there is no pending Character
Studio edit. `flushPendingDataEditAutoSave()` is a pending-only operation;
calling its persistence and cache-refresh path unconditionally while iOS takes
a background snapshot causes `0x8BADF00D` shutdown watchdog terminations.
File restore/merge flows must finish the user-visible restore and then stop.
They may mark database optimization as recommended, but must not start the
shared `Database Optimization` task automatically. Keep the user wording at
that level; technical phrase-link details belong in code and docs, not restore
progress UI.
My Data owns document pickers explicitly: normal Backup File restore and
Advanced Sentence Library import share one active importer kind plus a separate
presentation flag, while the reusable export modifier owns export presentation
only. Do not attach competing file importers to the same DataEdit screen, and do
not clear the importer kind from the `isPresented` setter; SwiftUI may dismiss
the picker before calling completion, and the completion still needs to know
which import action to run.
Database Optimization is guarded by an input fingerprint: optimization
algorithm version, sentence DB key stats, visible phrase words, and extracted
page sentence text. Imports may conservatively mark optimization dirty, but the
fingerprint wins; if the current fingerprint already matches the last optimized
fingerprint, Radix skips the pass and reports that the database is already
optimized.
Settings starts Database Optimization before computing that fingerprint, so the
UI can immediately show progress instead of appearing frozen while phrase and
sentence snapshots are prepared. The phrase-word snapshot for Settings
maintenance should be built through `PhraseRepository.activeSentencePhraseLinkWords()`
and the async settings helper, not by ad hoc `fetchAllPhrases()` scans in the
store.
The manual Settings optimization intentionally runs the fuller maintenance pass
even when the phrase-link fingerprint is current, because it also hides storage
cleanup that users should not have to understand as a separate operation.

## Performance Rules

Performance takes priority over non-essential features and implementation
convenience. When reviewing or modifying Radix, first identify any feature,
component, dependency, animation, background task, data operation, or
architecture choice that can materially degrade startup time, responsiveness,
memory use, battery life, scrolling performance, or stability. Clearly flag the
impact and its cause, then try to preserve the functionality by optimizing the
implementation. If practical optimization is not enough, recommend removing,
simplifying, deferring, or replacing the feature, but do not remove user-facing
functionality without explicit approval. Do not trade away correctness, data
integrity, security, accessibility, or maintainability for tiny benchmark wins;
prioritize changes that produce a real user-visible improvement.

Treat full-library work as suspicious by default. Any code path that touches all
sentences, phrases, saved pages, extracted pages, or dictionary entries must be
classified as import, restore, explicit maintenance, or background cache
rebuild work before it is allowed. SwiftUI body evaluation, row rendering,
card presentation, Study lists, phrase-card Examples, sentence-card display,
and backup previews must use paged or targeted repository queries instead of
loading whole databases just to count, find one item, or render a small list.
Before adding database work, ask whether it runs on every display, every
selection, every keystroke, every restore, or only after an explicit action.
If it can scan many rows, it needs one of these protections: an indexed query,
pagination, a batch lookup by stable keys, write-time preprocessing, a cached
snapshot with invalidation, or the shared `Database Optimization` task with
visible progress and fingerprint-based skip detection.

The common performance hazards in Radix are: full sentence DB fetches for
boolean/count checks, one SQLite lookup per visible row, phrase-link discovery
or Simplified/Traditional conversion in render paths, broad `LIKE` scans when
an indexed source flag exists, JSON export/import work mixed into visible
restore progress, and repeated master dictionary or phrase baseline loading
after each small edit. Prefer repository helpers such as
`querySentenceExamples`, `sentenceExampleCount`, batch normalized-key lookups,
stored sentence phrase hints, `ScriptTextConverter`'s bounded cache, and cached
variance baselines.
Do not cap user learning data just to protect weak code paths. Prefer soft
limits and visible storage health: warn when sentence libraries, added phrases,
extracted pages, or DB files become large, cap/chunk expensive operations such
as imports, exports, and backups, and keep ordinary Study/Browse access paged
and indexed. Current Settings storage health uses lightweight counts and file
metadata; it must not load full sentence or phrase records merely to summarize
database size.
2026-07-15 performance/clarity review: user-facing Settings shows one plain
`Optimize Database` action. It hides Simplified-storage cleanup inside that
action, but it no longer performs the expensive full phrase-link refresh.
Restore/import only marks optimization as recommended; it does not run
background optimization. Remaining performance-sensitive operations are
acceptable only because they are explicit actions rather than render paths:
portable backup/export serializes full data, Study > Sentences "delete all
matching results" fetches matching records so page-owned artifacts stay
consistent, and first pinyin phrase search may build the phrase pinyin index
from the merged phrase set. If any of these become noticeably slow, optimize
them before adding adjacent features.
2026-07-15 maintainability/performance pass: keep state machines single-valued
where possible. The Study section selector uses one focused-section enum rather
than three independent booleans, reducing impossible UI states and duplicate
title sync. Added Phrases, Conversation Practices, and Sentences are peer
in-place sections and no longer retain obsolete section-specific back-button
renderers. The high-priority `ConversationPracticeModels.swift` split is now
complete: pack decoding, validation, library mapping, topics, sentence
examples, favorite sentences, capture import, progress, and quiz rules have
separate model files. Remaining large-file refactor targets are
`RadixStoreDataEdit.swift`, `PromptModels.swift`, `FavouritesTab.swift`, and
`ComponentRepository.swift`.
Sentence search and phrase-card Examples should share the same phrase-aware
matcher in `RadixStudyPreferences` so target/detected phrase hints and
simplified/traditional query conversion behave consistently.
The root `Study - [section]` title menu is the Study section selector on every
platform. Do not duplicate it with broad in-content dashboard buttons for
Recent, Favorites, Added Phrases, Conversation Practices, Sentences, or
Checkpoints. Pages is reached from saved-page entry points instead of the Study
section menu, while persisted identifiers remain `savedPages` / `Saved Pages`
for compatibility. Study defaults to the `Sentences` focused section; selecting
the top-level Study item in the title menu also returns to `Study - Sentences`.
Keep the pinned Study controls visible when focused sections are active, do not
show a `Back to Study` button for normal switching, and clear the other focused
Study sections when one is selected. Do not reintroduce separate booleans for
these mutually exclusive sections.
The root title dropdown is now also the complete high-level navigation menu on
every platform. Its top section keeps the broad workspaces available:
`Browse`, `Pages`, `Study`, `AI`, `Data`, and `Settings`. `Pages` is a
title-menu and larger-screen sidebar peer so saved-page work does not look like
a hidden Study or Browse mode, but it still reuses the existing saved-page Study
implementation and persisted identifiers. Browse appends a flat,
headerless list ordered as Dictionary, `Text to Page`, `Image from Album`,
`Image from Files`, then saved pages; the global Camera button remains the
instant camera action.
Study appends all study sections including Checkpoints, AI appends AI tasks, and
Data appends `Backup Files` / `Advanced Pro`. On iPhone this is the primary
navigation experiment and the bottom tab bar is hidden; on iPad and Mac the
sidebar remains as a larger-screen parallel affordance for now.
Mac Catalyst does not show the same native navigation title bar as phone/iPad,
so the detail pane owns a visible root title row. Keep it driven by the shared
`detailPaneTitle` / title picker logic so Catalyst shows contextual titles such
as `Browse - Dictionary`, `Pages`, and `Study - Sentences` instead of falling
back to the app name. The content area
should not immediately repeat the same section label shown in the root title.
For Browse, the root title menu is the source selector for Dictionary and page
creation on every platform. Saved-page entries route to Pages. Do not duplicate
Browse with an in-content `Sources` button or source panel entry. The global
`Camera` action routes to Camera/capture and opens the camera sheet once by
default; after that sheet is dismissed, the full
capture workbench remains visible with album, file, clipboard, and camera
intake options.
Study > Sentences search should not feel narrower than phrase-card Examples:
typing a search resets the sentence filter to All, and searched results use a
larger page size so phrase searches are not mistaken for missing examples.
The minimum character-count slider is an additional filter and should leave the
search field flexible rather than becoming another management screen.
Extracted sentence rows reuse the shared Conversation Practice sentence controls,
lazy list, row, and sentence card, resolving back to the canonical sentence
database record so active selection, Chinese/English display, script switching,
phrase chips, read-aloud, and favorites stay aligned.
On iPhone, those shared sentence rows prioritize reading space: the row shows
only the selected display language (Chinese or English), omits pinyin and row
chevrons, and wraps long portrait sentences instead of squeezing them into one
line. On iPhone, the `Study - [section]` title dropdown is the Study section
switcher for Recent, Favorites, Saved Pages, Added Phrases, Conversation
Practices, Sentences, and Checkpoints; do not duplicate those choices as broad
in-content Study buttons. Keep only controls that affect the current Study
section, such as Saved Pages sorting or Sentences paging/search/display tools.
Every Study section should preserve the title menu and History strip; embedded
workspaces such as Added Phrases must not hide the parent navigation bar.
Conversation Practice and extracted sentence lists should reuse the same
phone sentence control layout as Study Sentences: page navigation and
Chinese/English display controls stay compact in one local row where possible.
Study Sentences, extracted sentence pages, and Conversation Practice use the
same default visible sentence page size so the row ranges feel consistent across
sentence-based Study surfaces.
Conversation Practice must not reserve a bottom action bar or framed card shell
on any platform; the sentence list is the primary surface. Flashcards and Quick
Quiz live in the compact top tools menu, while the local Translate Quiz feature
has been removed. Future translation practice should route through AI-backed
workflows instead of reintroducing local quiz code.
Per-row favorite and overflow actions should not permanently consume phone
sentence-row width; keep them in long-press context menus or compact tool menus
except while selection mode needs a visible checkbox. iPad and Mac keep the
richer compact row with pinyin in Chinese mode.
The extracted-sentences reader must render from a page-scoped SQLite sentence
query plus cheap page-sentence fallbacks; do not scan the whole sentence database
or rebuild `SentenceExampleRecord.fromAICleanedPage` in the display path.
For large extracted pages, page the `AICleanedPageRecord.sentences` array before
building `ConversationPracticeItem`s or looking up canonical sentence records;
the visible list should touch only the current page of rows during SwiftUI body
evaluation.
The extracted-page reader keeps a small state cache for the current visible
sentence page and renders long cleaned page text as a collapsed preview by
default. Avoid reintroducing row DB lookups, item construction, or full-page
text rendering directly into the reader body.
When a visible extracted-sentence page needs canonical records, use the
repository batch lookup by normalized keys instead of one SQLite lookup per
row.
Repeated Simplified/Traditional conversion goes through `ScriptTextConverter`'s
bounded cache. Keep row-level display code on shared conversion helpers instead
of calling `CFStringTransform` repeatedly from SwiftUI body paths.
Sentence phrase maps use the same longest non-overlapping selection rule as page
phrase discovery: when candidate phrases overlap inside a sentence, the longer
phrase owns that span and shorter overlapping chips are suppressed.
Extracted-sentence import, backup restore, and startup migration preprocess
sentence `phrase_hints` by discovering all known 2+ character phrase-library
matches against the sentence's simplified storage form. Sentence cards should
not inspect those phrase hints in the render path; sentence rows and cards are
terminal reading surfaces. Phrase buttons and character animation in the
sentence card must use precomputed or explicitly requested data only, and must
not create nested preview stacks.
Extracted-sentence readers should not display the full cleaned page body or
split the cleaned body into fallback sentence fragments during SwiftUI display.
If an extracted-page record has no saved sentence array, ask the user to
re-extract instead of doing whole-page text processing in the reader.
When a phrase is opened from a sentence card, Radix stores a narrow sentence
return context and shows a compact `Sentence` return action on the phrase card;
ordinary phrase previews still clear that context.
On phone, the Study preview return pill for a sentence card must derive from
the active sentence example's real source before falling back to a Conversation
Practice topic, so unrelated selected topics cannot leak into page/extracted
sentence previews.
Sentence-card presentation should go through RadixStore helpers
(`presentSentencePreviewInSidebar`, `sentencePreviewPhrases`, and
`sentencePreviewReturnTitle`) instead of each Study surface rebuilding the
sentence-as-phrase, phrase list, speech, and return label independently.
Sentence-card destructive actions should delete through `RadixStore` so the
canonical sentence database, favorite compatibility records, and any owning
extracted-sentence page record stay in sync.
Settings reference pages such as Glossary and Credits must not push the user
out of the tab shell on iPhone. Present them as dismissible reference sheets
with an explicit Done control so users can always return to Settings, Study, or
another primary tab.
Study > Sentences can batch-delete the current searched result set after
confirmation. Batch and single sentence deletes share the same `RadixStore`
path so sentence database rows, favorite compatibility records, and
page-owned extracted-sentence records are removed together.
Study > Sentences also supports a visible page-local selection mode for
deleting specific sentences from a search or filter result. Keep selected
sentences visible, clear the selection when the page/search/filter changes, and
route selected deletes through the same `RadixStore` sentence deletion path.
Keep page reset, selection reset, delete, and post-mutation refresh behavior on
the shared Study Sentences helpers instead of repeating those state updates in
individual buttons.
Study > Sentences must treat SQLite as the live query engine, not as a JSON
blob cache. The sentence table owns count, search, filter, paging, row fetch,
upsert, and delete through `RadixStudyPreferences.querySentenceExamples` and
related repository helpers; SwiftUI should render the current page result
instead of repeatedly loading and ranking every sentence record.
Sentence source filters should use the indexed source flag columns maintained
beside the JSON payload, not broad `source_text` scans, for common page-linked
and practice-linked Study Sentences queries.

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
- Mac Catalyst enters the iPad-style split shell directly instead of routing
  through size-class root switching, and avoids root-level dynamic type forcing.
  Its `NavigationSplitView` columns must not set `.navigationTitle` or
  principal title toolbar items; in-content headers own workspace identity and
  avoid SwiftUI title-merge crashes.

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
The forwarding properties in `RadixStore.swift` are compatibility shims for
existing views and extensions. Prefer using the focused state/adapters directly
for new work, and retire passthrough properties incrementally when touching the
owning surface so the facade does not keep growing.

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

### File-size pressure points

Keep future refactors opportunistic and behavior-preserving:

- Keep the completed conversation-practice model split intact. Add new
  conversation-practice behavior to the narrow file that owns that concern
  rather than growing `ConversationPracticeModels.swift` again.
- Treat `RadixStoreDataEdit.swift`, `PromptModels.swift`, `FavouritesTab.swift`,
  and `ComponentRepository.swift` as the next large-file candidates for the
  same focused extraction pattern already used elsewhere. Avoid adding
  unrelated responsibilities to those files while making feature changes.
- Suggested future split order: move import/restore orchestration out of
  `RadixStoreDataEdit.swift`, split built-in prompt templates from prompt task
  metadata in `PromptModels.swift`, continue moving focused Study state and
  lifecycle helpers out of `FavouritesTab.swift`, then extract
  `ComponentRepository.swift` query/index helpers by responsibility.

### Reuse-first rule

Before adding a new learning surface, search for an existing Radix surface that
already owns that behavior and extend it instead of building a parallel version.
This is especially important for sentence rows, Conversation Practice previews,
Phrase Library sheets, phrase/sentence/character info cards, page artifact
chips, and AI task flows. New code should introduce a second renderer or
workflow only when the existing one cannot reasonably express the behavior, and
the reason should be documented in the same change.
SwiftUI helper views in `App/` and `Views/` should have visible call sites; do
not leave superseded alternate rows, cards, menu content, or one-off preview
wrappers behind after a redesign.
The obsolete local page-quiz view in `BrowsePhraseExtractionSheet` and an
unused phrase-review cycle hint were removed after a call-site sweep. The old
standalone `BrowseOCRReviewSheet` was also removed; OCR review now uses the
shared AI task flow. A follow-up single-reference view sweep across `App/` and
`Views/` is clean; `Views/AILinkTemplateEditor.swift` is live through the
`AI Templates` toolbar sheet in AI Link.
Character and phrase info-card action pills share `InfoCardActionPill`; keep
notes, phrase lookup, and related small info-card actions on that component so
their spacing, radius, borders, and accessibility affordance do not drift.
Quick phrase and character edit sheets keep `Save` in the top header because
the keyboard can cover bottom controls; bottom rows are reserved for management
actions such as `Delete` or `Revert`. Phrase editing exposes English meaning
before notes so the info-card editor is not notes-only.
`InfoCardActionPill`, character info tiles, and the regular Character Detail
header/action controls use the shared Radix surface/pill primitives; keep new
info-card chips on those helpers rather than hand-copying rounded backgrounds.
Character info card component strips use explicit rows rather than lazy grids.
Character Detail metric icons use the shared compact icon surface, and the
header's descriptor-driven metric chips use explicit `ViewThatFits` rows/stacks
rather than a lazy grid.
Phrase info cards keep sentence and ordinary phrase content in separate
top-level stacks and render animation tiles as explicit rows rather than a lazy
grid, avoiding SwiftUI composition crashes while preserving the same controls.
Phrase-card animation page chips intentionally use a plain horizontal scroll,
not an embedded `ScrollViewReader`, because crash logs have shown SwiftUI retain
failures while rebuilding phrase cards during Browse/page-phrase workflows.
Small square info-card icon buttons use `radixIconButtonSurface` so favorite,
edit, and read-aloud buttons keep one radius, background, and tap shape.
Phrase-library actions follow one rule: the normal Phrase Info Card already
represents a known library phrase, so it does not show `Add Phrase` or
`Revert Phrase`. It may show `Delete Phrase` only for user-added non-base
phrases. `Revert Phrase` belongs in advanced phrase editing/data surfaces.
Page-level Show/Hidden remains separate from deleting a phrase.
Single-phrase creation uses the shared quick phrase editor. Keep the convenient
entry points in Study Added Phrases, Search no-results, and Browse Page Phrases
on `openNewPhraseEditor(...)` so the add form, validation, and save path remain
one implementation. New single-phrase saves must reject phrases already present
in either the base phrase DB or the added phrase DB before writing. All visible
single-phrase add launchers use `AddPhraseLaunchButton`, and new-phrase entry
points present `AddPhraseSheet` rather than a separate editor UI.
Compact destructive icon buttons such as imported Conversation Practice delete
also use that helper while keeping their local tint. Sentence browser row
action menus use the same helper for their compact icon surface.
My Data backup preview navigation/stat rows share one row renderer so labels,
trailing counts, chevrons, phone subtitle behavior, and icon treatment stay
aligned. Their compact leading icons use the shared icon surface helper.
My Data backup action cards, recent-backup rows, backup-preview badges, and
advanced-export option cards use the shared Radix pill/surface primitives for
simple leaf styling, including compact option and tools info icon surfaces.
My Data backup affordances use `RadixAccent.primary` for brand-primary tinting,
while destructive restore actions keep their semantic orange styling.
My Data backup actions use explicit rows/stacks instead of lazy grids.
My Data file handling uses `Create Backup` to create a new file from memory,
`Merge Backup` to combine the file and memory so both contain the merged
contents, and `Restore Backup` as the advanced destructive path that replaces
memory with the file.
Backup preview headers and Study checkpoint action icons use the shared icon
surface helper.
Backup-content disclosures and backup-preview character tiles are part of that
same shared surface vocabulary. Backup preview character and phrase summaries
use explicit rows instead of lazy grids. Keep workflow-specific gradients local
to their owning section.
Study saved-page artifact indicators use the shared icon surface helper and
text artifact actions use `radixPill`, so collapsed row chips stay aligned with
the broader surface vocabulary.
Conversation Practice import previews also keep their header icon on that
surface helper. Conversation Practice generation cards use the same compact
header icon treatment, shared card surfaces, and pill chips for target counts
and situations. Practice drill score/review counters use `radixPill` instead of
local padding/background chains.
My Data Advanced Exports keeps the AI-coding-agent purpose in the section intro
and tooltip details; option subtitles should stay short and identify the
exported file rather than repeating that purpose on every row.
The My Data segmented picker owns the current section name; do not repeat
`Backup File` or `Advanced Exports` as an immediate in-card heading below it.
Chevron rows with an icon, title, optional subtitle, and trailing disclosure
indicator share `RadixChevronRow` in `Views/RadixChevronRow.swift`. Tappable
menu-selector labels wrap it through `RadixMenuSelectorRow`; AI Link task/source
dropdowns, AI quantity selection, collapsed AI result text, and Conversation
Practice topic selection, and Components Explorer disclosure headers should keep
row icon size, chevron, border, radius, and missing-state tint there instead of
hand-copying row styling.
Compact menu buttons or disclosure labels with an icon, label, and chevron use
`RadixCompactChevronLabel`; keep page action menus and phrase-review filter or
action menus, text-only page jump menus, and icon-only menu split buttons on
that helper. Navigation title dropdown labels and compact row expanders should
also use it when they are only title/icon plus chevron, so toolbar-scale
chevrons, spacing, and scaling do not drift from the full-width row primitives.
Character Studio's compact dictionary-field expander follows this same helper
instead of separately laying out the text and disclosure chevron.
Focused Study workspaces share one local back-pill renderer so Conversation
Practice, Sentences, and future full-screen Study sections keep return action
spacing and tint aligned.
On iPhone, Added Phrases preview stays inside the focused review workspace as
the compact inline detail strip above the phrase tiles; tile taps must not push
the global Phrase Info Card/sidebar preview there. Added Phrases status taps
optimistically update the local in-memory phrase state before deferred
persistence. Added Phrases review candidates are cached on the store and copied
into the review screen locally so opening the grid and tile feedback stay
immediate.
Study dashboard shortcuts are a fixed descriptor-driven action set and render
as explicit rows rather than a lazy grid; keep their actions switch-based
instead of storing escaping closures in transient row data.
Study utility chips such as Clear Recent, saved-page sort, and active-page
resume signals use `radixPill` for compact rounded feedback.
Small previous/next pager arrows and row-accessory disclosure arrows also use
`RadixCompactChevronLabel` as the icon label while keeping their owning button
styles and row surfaces local. Expanded/collapsed text toggles such as AI
result visibility should also use the compact helper when the visible control
is only text plus a chevron. The AI Link result header keeps its icon on the
shared compact icon surface.
UI polish passes should flow through `Services/RadixTheme.swift` primitives
(`radixCard`, `radixPill`, `radixSurface`, shared spacing/radius/icon sizes,
and haptic helpers) before touching many screens. Preserve the asset-catalog
accent as Radix's primary identity; do not wholesale replace the app accent or
drop in broad external bundles without reviewing each affected workflow against
`UI_INTENT.md`. Apply those primitives directly to new or simple leaf
components first, including Capture source/import action icons and simple
Browse source-menu and dictionary-help icon surfaces. Capture step-number chips
use the same helper with a circular radius. Capture's fixed Camera/Album/Files
source actions use explicit `ViewThatFits` rows/stacks rather than a lazy grid.
Small modal header icons for Add Phrase and Character Studio, and root action
card icons use the same surface helper. For root-level
onboarding/action content, keep simple icon surfaces on the same helper,
including compact sidebar checkpoint action icons, and keep onboarding step rows
on `radixSurface`. Static Settings and navigation guide icons can use the helper
directly. For complex existing SwiftUI
surfaces, especially AI Link and info cards, prefer surgical spacing/color/layout
edits that preserve the current modifier structure; broad mechanical replacement
of background, clipShape, and overlay chains has already produced runtime
regressions even when tests and builds passed.
Shared chevron rows, Add Phrase headers, Character Studio headers, root action
tiles, script controls, welcome steps, and navigation guide icons use
`RadixAccent.primary` for brand-primary tinting.
Root sidebar active tabs and checkpoint affordances use the same accent alias.
Capture source controls and Browse source-menu selection affordances also use
`RadixAccent.primary` for brand-primary tinting.
Simple leaf brand accents in AI result headers, Settings, Paywall, Glossary,
inline help, phrase read-aloud controls, contextual return buttons, and
interaction hints also use `RadixAccent.primary`.
Phone context preview return buttons use the shared surface helper while keeping
their contextual labels and primary accent tint.
AI template cards, Apple stroke lookup summaries, Advanced Export accent
gradients, sentence action icons, and phone-tab active fills also use the alias.
The direct `Color.accentColor` audit is complete across `App/`, `Views/`,
`Models/`, `Services/`, and `ViewModels`; only the alias definition in
`RadixTheme` should reference it directly.
Add Phrase input form sections and text editors, plus Capture source cards,
workflow hints, previews, saved-page rows, and character editors, use the shared
surface helper for simple rounded backgrounds and borders.
Shared haptics are wired into focused mutation moments: adding phrases, importing
AI pasted phrases, removing an added phrase from the current review batch,
saving phrase notes, saving/reverting/deleting edited characters, deleting
added-phrase batches or single phrases, erasing local app data, importing or
deleting Conversation Practice packs, promoting corrected OCR pages, and
completing backup restores.
Browse source status messages use `radixPill` for their inline feedback chip.
Browse filter menu chips use `radixPill` while preserving picker-owned height.
Browse page-phrase taps should own phrase preview state without also setting a
character preview; on iPhone, the page-phrase sheet dismisses after opening a
phrase so Browse can show one stable preview surface.
Smart Search result headers use `radixCard` for their compact summary surface.
Smart Search example buttons are a fixed descriptor-driven three-action set and
use explicit `ViewThatFits` rows/stacks rather than a lazy grid.
Paywall benefit copy is a short fixed list and stays in a simple stack rather
than a lazy grid.
Compact management rows such as checkpoints and other-device summaries also use
the icon surface helper for leading status glyphs.
Components Explorer filter picker rows, compact inline help/tips panels, and
interaction hint containers use `radixSurface` for their simple rounded
backgrounds.
Simple status and summary surfaces in Settings, Paywall, Add Phrase review,
Capture messages, and phrase-discovery feedback/results also use
`radixSurface`. Conversation Practice import status banners use the same helper
for success and error feedback.
Paywall plan cards, hero panels, loading states, and fixed benefit chips share
Radix surface and pill primitives while preserving local paywall tint choices.
Quick phrase/character editor notes, meaning fields, and compact dictionary
expanders use the shared surface helper for their rounded editing containers.
Components Explorer section wrappers, filter buttons, and character tiles also
use the shared surface helper while keeping their explicit grid behavior.
Smart Search example/help panels, phrase-match rows, search chrome, and compact
result tiles use shared surface/pill primitives for their rounded containers.
Browse source disclosure wrappers, source-menu rows, compact count chips, and
the page translation editor use shared surface helpers for simple containers.
Added Phrase Review detail feedback panels and explicit review tiles use the
shared surface helper while preserving fixed paging and explicit row layout.
Phrase table headers and list viewports use the shared surface helper for their
simple rounded containers while preserving sheet detent behavior.
Phrase lookup list containers, phrase-length filter chips, and photo import
action rows use shared surface/pill helpers while preserving their fixed sizing.
Breadcrumb chips, Browse dictionary filter toggles, and reusable search example
buttons use shared surface helpers while preserving their compact control sizes.
Root sidebar checkpoint panels, preview shells, root action tiles, empty states,
and compact script toggles use shared surface helpers for simple containers.
Root-level and Browse editing/report sheets declare their expected detents at
the `.sheet` presentation boundary so modal height behavior stays consistent
without restructuring the sheet content views.
AI Template editing, page AI orientation, Conversation Practice flashcards,
character quiz, translation quiz, and pasted Practice import sheets also declare
their expected detents at the presentation boundary; drill sheets use full
height, while compact orientation/import workflows allow medium or large.
Camera capture sheets in Capture and Browse also declare full-height sheet
detents so live image capture keeps a predictable workspace.
Added Phrase Review keeps its review surface and phrase grid directly framed
with `maxWidth`/`maxHeight`, using fixed platform page sizes instead of
geometry-driven adaptive paging so SwiftUI does not rebuild the sheet through
measurement feedback. Its phrase grid renders explicit rows instead of
`LazyVGrid` for the same reason; keep the status tool controls on explicit rows
too.
`CLAUDE_IDEAL_HANDOFF.md` summarizes the current UI-polish completion estimate,
remaining audit work, and crash lessons for handing the finishing pass to Claude.

### Data and persistence

- Character dictionary: JSON base data plus `component_map_changes.json` overlay.
- Phrases: bundled SQLite plus the user-added phrase database.
- Dictionary variance audits derive added/missing characters from the in-memory
  overlay and cache the immutable bundled phrase word set; do not reparse the
  bundled dictionary or reopen/scan the master phrase database on every
  Character Studio save.
- Curated Study lesson sentences must be Phrase DB-backed, or referenced by a
  practice-set layer that points to Phrase DB records. Do not build a separate
  lesson-only Chinese sentence store that bypasses Radix Phrase cards,
  Character cards, favorites, notes, Browse inspection, or review state.
- Study-owned favorite sentences are persisted as `FavoriteSentenceRecord`
  snapshots inside the separate Sentence Library and exposed as a generated
  `Favorite Sentences` Conversation Practice library, so sentence review uses the
  same flashcard, quiz, translate, speech, and Sentence Library transfer path as
  other sentence records.
  Sentence info cards pass an explicit `.sentence` favorite target, while
  ordinary phrase cards use `.phrase`, so the star cannot silently switch
  between character, phrase, and sentence semantics. Conversation Practice
  sentence preview cards also expose an explicit read-aloud button for the full
  sentence. On iPhone, the preview return button names the active Conversation
  Practice theme rather than a generic sentence list. Phrase and sentence
  preview cards show the meaning text directly, and character preview cards show
  the definition directly, without redundant section headings.
  Character and phrase information cards do not inline sentence examples.
  Examples appear through an `Examples` action, show a Chinese plus English
  sentence list without pinyin first, and open the shared sentence information
  card on selection.
- Portable backup: `UnifiedPackage` schema 5, with legacy backup decoding retained.
- Bundled standard data imports additively once on startup from
  `radix_unified_backup.json`, guarded by `RadixPreferenceKey.standardDataImportID`.
- `RadixPreferenceKey` is the canonical list of stable persisted identifiers.
- `RadixPreferenceStore` is the platform-neutral storage boundary.
- Apple persistence uses `RadixPreferences`, backed by `UserDefaults`.
- `RadixStore`, `EntitlementManager`, and the phrase database location manager
  accept an injected preference store.
- On iPhone, character or phrase previews opened from a page Source view show a
  contextual return button named for that page, not a generic Browse label.
- In Browse, the top `Browse [page name]` navigation title is the quick
  saved-page selector for Dictionary and saved pages. The open-page card does
  not have a separate header row or source button; compact character count and
  page-specific controls live in the local control row.
- Browse saved-page selection is exposed through state adapters; keep selection
  changes explicitly published so the navigation title menu, page card, and grid
  do not drift out of sync.
- Dictionary Browse uses a visible help disclosure in its header. Capture/import
  sources live under Camera/capture rather than inside Browse, because Browse is
  now for choosing and inspecting Dictionary or saved pages.
  saved pages, clipboard, album, and file inputs. Dictionary grid controls
  such as components, script choice, and filters live on their own compact row
  instead of crowding the source/navigation row.
- The page-centered direction requires a page artifact model before destructive
  cascade behavior is added. Corrected OCR pages, translations, extracted
  sentence packs, page-created conversation practice, and page-local notes are
  page-owned artifacts. Added phrases, favorites, global notes, and
  reusable practice progress are linked learning material that should not be
  silently deleted with a page. Page phrase extraction records link extracted
  non-base phrase words back to the saved page that produced them, including
  user-added phrases that already existed before the current extraction. These
  links travel in backup and are removed only as page links when the page is
  deleted; the phrases stay in the global phrase database.
- Imported Conversation Practice packs may carry an optional saved-page source
  link with page ID, title, created date, and optional fingerprint. Page AI
  imports attach this link automatically; old title matching remains only as a
  fallback for legacy packs.
- Deleting a saved page now uses a store-level deletion impact summary and
  removes explicit page-owned descendants: corrected OCR pages and
  source-linked imported Practice packs. Linked sentence favorites and reusable
  Practice progress are summarized as kept learning memory rather than silently
  deleted. The delete alert should always show both `Will remove with this page`
  and `Will keep as learning memory`, even when either list is currently `none`.
- Browse owns saved-page selection and tile inspection. Explicit page Study
  actions open the internal saved-page learning workspace for page phrase
  lists, Practice packs, translation, quiz entry point, corrected pages,
  favorite sentences, and Practice progress. Study no longer exposes Saved
  Pages as a local section menu item, and Pages is not a primary navigation
  destination. Recent and Favorites remain Study review scopes, while Added
  Phrases, Conversation Practices, Sentences, and Checkpoints remain Study
  sections. Browse source-inspection close requests use the
  `shouldCloseBrowseSource` presentation flag; do not reintroduce Browse Pages
  state for normal page navigation.
  Favorite Sentences belongs inside Conversation Practices rather than appearing
  as a duplicate shortcut; when favorite sentences exist, opening Conversation
  Practices from Study should default to that `Favorite Sentences` topic.
  These Study navigation and control rows stay pinned while review content
  scrolls so users can switch scope or use shortcuts from deep in a long list.
  Fuller guidance belongs in the guided title Help menu rather than persistent
  text rows.
  Pages uses a dense collapsed numbered list with no vertical gaps between rows
  so large libraries remain scannable. Tapping a page row expands that single
  page to reveal the Actions menu, Source shortcut, status feedback, and
  artifact buttons; the collapsed row itself is not a navigation shortcut. The
  row matching the currently selected saved page is highlighted so returning
  from Source makes the active page easy to identify.
  Keep this list lazy and avoid full per-page phrase scans during row drawing;
  row indicators may use recorded extraction links or existing caches, while
  full pinyin-sorted phrase lookup happens when the user opens `Phrases`.
  Collapsed row indicators and expanded artifact chips are rendered from the
  same page-artifact descriptors so labels, icons, and actions do not drift.
  The `Phrases` chip opens all dictionary and added phrases found on the page
  in the shared Phrase Library sheet used by the information-card Phrase
  button. Expanded saved-page rows avoid inline stats such as character counts,
  dates, phrase counts, sentence counts, favorite counts, and progress counts.
  Artifact chips are text-only when the visible word already names the action,
  and use compact type so the page card remains scan-friendly on iPhone. Page
  phrase lists are sorted by pinyin and dismiss after phrase
  selection on sidebar layouts so the selected Phrase Info Card is unobstructed.
  Source-linked sentence-extraction packs are labeled `Sentences`; generated
  page conversation packs are labeled `Conversation`.
  Study owns learning
  artifacts, AI workflows, and saved-page deletion. Browse owns page inspection
  controls that only make sense while looking at the page, including editing
  the page text and choosing visible page phrases. The explicit `Source` action
  in Pages opens that saved page's source content directly in Browse and keeps a
  contextual return path back to Pages. Corrected OCR pages can be promoted from Study so
  the corrected text becomes the main page while preserving the main page ID and
  its linked learning artifacts; the old OCR can either be kept as a separate
  archived page or discarded during promotion.

Never change an existing preference key, enum raw value, backup field, or review
status without an explicit migration and compatibility test.

### Portable core

`Package.swift` defines `RadixCore`, which contains platform-neutral models and
compatibility contracts. Current portable contracts include:

- backup and profile models/codecs
- phrase-review status behavior
- navigation, tab, script-filter, and restore-mode identifiers
- preference keys and the preference-storage interface
- saved-page naming, recent-page selection, and page artifact ownership rules
- Conversation Practice source-link and sentence-reference metadata for
  page-derived practice packs
- search query parsing, pinyin/chinese text classification, phrase result
  sorting, phrase-length rules, added-phrase review rules, Study review rules,
Browse page phrase matching, shared page actions, and component search indexing

The portable test suite currently contains 67 tests across eight suites.
If a function can be tested without SwiftUI, UIKit, AppKit, file pickers,
camera, speech, or StoreKit, prefer `Models` or `Services` over view or
view-state ownership. Android migration should start from these portable
contracts, then repository/query services, then state orchestration, with UI
ported last.

## Current Product Direction

Radix is a Chinese learning workspace where material encountered in daily life
becomes personal study material. The accepted product loop is
`Scan -> Review -> Practise -> Keep`: scan a page from the world, review its
characters/phrases/context, practise from that material, and keep everything
connected for later. Lead with learner outcomes rather than raw feature names
such as OCR or saved-page storage.

Near-term work should be incremental rather than broad navigation reshuffling:
make Pages feel like the center of saved-page work; keep generated artifacts
visibly tied to their source page; improve empty states with one clear next
action; continue impact summaries for destructive actions; add lightweight
resume signals only where useful; keep AI manual/API workflows using the same
method vocabulary; and check iPhone one-handed ergonomics.

Study Help names the page-first mental model as
`Pages -> Artifacts -> Practice -> Memory -> Checkpoints`. Empty Pages offers
one `Create Page` action that opens Camera/capture while preserving a return
path.
Page-derived Conversation Practice topics should surface their saved-page origin
in Study topic summaries, and keep that source cue visible alongside practice
progress when the user opens the practice section.
Saved-page deletion impact text must match actual ownership: corrected pages,
translations, page phrase lists, and page-derived practice packs are removed
with the page, while standalone learning memory such as added phrases, favorite
sentences, and reusable practice progress is retained.
Saved-page resume signals should remain selective: the collapsed Pages list may
show last-viewed context for the active page or the top page in `Viewed` sort,
but should not add date/status text to every row or simply mark row 1 in other
sort modes.
Page AI actions should consistently name the two methods as `Copy to AI Chat`
for copy/paste handoff and `Run Automatically with Gemini` for in-app Gemini
execution. Avoid mixing older labels such as Manual AI Link, Gemini API,
automatic AI, another AI app, or copy-and-paste method in user-facing
page-action flows. The page-action AI orientation sheet uses `Copy to AI Chat`,
`Run Automatically with Gemini`, and `your chosen AI chat` wording.
Study Help should explain the page-first mental model directly:
`Pages -> Artifacts -> Practice -> Memory -> Checkpoints`, with saved pages as
the center, page-owned artifacts attached to the source, practice growing from
real text, learning memory retained, and checkpoints as the safety net.
iPhone saved-page ergonomics should keep collapsed rows compact for scanning,
but make expanded page controls, especially `Actions` and `Source`, wider and
easier to tap once a row is opened.
Saved Pages remains a persisted compatibility scope internally, but it should be
opened through Pages entry points rather than exposed as a normal Study section.
Visible empty states and capture inventory labels should say `Pages` / `Create
Page`; keep `Saved Pages` for compatibility identifiers, backup inventory, and
places where the distinction from sentence/phrase memory is useful.
Sentence architecture is converging on a canonical Sentence Example database:
favorite sentences, page sentences, Conversation Practice items, and future
practice packs should become flags, source links, ordered memberships, or
progress records over sentence examples rather than separate sentence stores.
Canonical records now provide exact normalized deduplication, Sentence Library
portability, source/character/phrase/page lookup helpers, automatic capture
from Conversation Practice packs/favorite toggles, and legacy Favorite
Sentences backfill. Imported/page-generated Conversation Practice packs now
store ordered sentence references back to canonical examples, so packs act as
grouping and sequencing metadata rather than another sentence database. Existing
stored imported packs are migrated idempotently when Study or the store loads
Conversation Practice, so old practice sentences enter the sentence database
without requiring re-import. The
Favorite Sentences practice topic should be built from canonical favorited
sentence examples while keeping old favorite records only as compatibility data
until a fuller migration removes the duplicate store. Sentence Library JSON
import applies canonical sentence examples before legacy favorite-sentence
records so favorites overlay into the sentence database instead of being
overwritten by import ordering. Fast sentence database import in Study validates
the SQLite sentence table, creates a safety snapshot, then either merges through
the canonical upsert path or replaces through SQLite backup restore. Favorite
toggles and sentence deletion update both the canonical sentence flag and the
legacy compatibility list so old favorite records cannot resurrect deleted or
unfavorited sentences. Sentence Library JSON export prepares the canonical
sentence store before packaging so old imported practice packs and legacy
favorite sentences are captured even if Study has not been opened in the current
app session. AI outputs may include a
`[Radix Capture JSON]` block containing `sentences` or `sentence_examples`;
Radix can parse those blocks into canonical sentence examples with optional
source metadata. Approved OCR corrections update saved-page text only and do
not automatically add OCR-derived sentences to Study. Quiz output remains
intentionally uncaptured until its
interactive flow has an explicit structured return path that does not reveal
answers early or scrape ordinary chat prose. Study exposes a `Sentences`
section that opens the Sentence Examples browser with a single compact source
menu for All, Favorites, From Pages, and From Practice records, plus search and
row actions for favorite, delete, copy Chinese, and opening sentence origins.
The browser should reuse Conversation Practice's shared sentence controls
(range/page navigation, Simplified/Traditional plus Chinese/English), shared
sentence row, and sentence info-card preview path rather than creating a
parallel sentence UI. Shared sentence UI primitives live in
`App/PracticeSentenceSurface.swift`; keep Conversation Practice and the Sentence
Examples browser as callers, not owners, of that row/control surface.
Sentence source/page origin should stay out of the default row, but a selected
sentence must show a compact `From ...` origin label and surface direct
`Open Page` and/or `Open Practice` actions when the source metadata can
navigate there.
The `Practice Again` sentence action builds a temporary Conversation Practice
library from canonical sentence examples and reuses the existing Flashcards
flow instead of creating another practice UI. The sentence edit action updates
the canonical sentence example record in place and synchronizes legacy favorite
compatibility records when the sentence text or favorite state changes.
Conversation Practice progress records now carry optional canonical sentence
IDs and normalized sentence keys. New review and quiz attempts attach that
identity when available, while old pack/item progress records remain readable
and are upgraded the next time the matching item is practiced.
Before changing any screen, apply `UI_INTENT.md`'s Design decision rules:
preserve visible return paths, fight for content space, and remove duplicate
meaning before adding new labels, rows, switches, or cards. Balance those rules
with the documented guardrails for orientation, discoverability, breathing room,
accessibility, and visible state changes.
App-wide inline alerts, notices, and status messages should appear on the next
row below their related controls, not beside them. This keeps action rows from
being squeezed and makes the message read as feedback rather than another
control. The Sentences browser status message follows this rule below its page
and display controls.
Search treats the editable search field as the single owner of the current
query. Result headers summarize counts and local result controls without
restating the query as a second title. The search field keeps decorative search
iconography at the leading edge and groups actions such as clear and Recent
Searches at the trailing edge.
Settings separates AI configuration by user goal: `AI Link` chooses where
manual prompts open, `Automatic AI` owns Gemini key/model setup for direct
Radix actions, and `Manual AI Keys` stores non-Gemini provider keys for
copy-and-paste AI Link workflows.
Gemini keeps a separate latest-device-key preference in addition to the portable
backup field. A current or retained local Gemini key must survive checkpoint and
backup restores; a backup Gemini key is used only when the device has no local
Gemini key to retain.
History is the user-facing name for the app's working memory strip: it helps
users recall recently inspected characters and phrases while searching, browsing
saved pages, or following item details. Do not treat it as global navigation.
Study shows the same strip so users can see sentence-origin phrase and character
previews being recorded, while Recent remains the deliberate review surface. My
Data represents stored memory, and AI Link or Settings should avoid the strip by
default unless a future workflow has an explicit exploration need. The shared
`BreadcrumbStrip` appears on Search, Browse, Character Breakdown, and Study, and
stays hidden on Camera, AI Link, My Data, and Settings. The leading History
clock must identify itself on hover and tap so the icon is not an unnamed
mystery control; tap disclosure should stay inline with the strip, not in a
popover that can collide with the navigation title.
Opening a sentence in Study, extracted sentences, Conversation Practice, or
Sentence Practice must not feed History by itself; long sentence lists would
swamp the working-memory strip. History should update only when the user
deliberately previews a character or phrase from that sentence. Keep those
updates cheap and capped: do not scan the phrase or sentence database merely
because a sentence row was tapped. The persisted History list is capped at
1,000 valid character/phrase items. History persistence normalizes incoming
display text to Simplified storage keys before validation, so Traditional
practice displays can still record the intended character or phrase. Phrase
Library sheets opened from a sentence record inspected phrases immediately even
when the phrase detail stays inside the sheet; tapping a phrase-card character
there records that character without opening another nested card. Keep History
display decisions in `HistoryStripDisplayPolicy` rather than duplicating route
checks inside SwiftUI views, and route deliberate phrase/character inspections
through `recordInspectedPhraseInHistory` / `recordInspectedCharacterInHistory`
so sentence-scoped sheets do not forget to update the strip.
Navigation help presentation belongs at `RootView`; do not attach popover or
context-menu presentation containers to the five equal-width tab buttons because
those wrappers can collapse the SwiftUI HStack to one visible destination.
On iPhone, iPad, and Mac Catalyst, ordinary navigation only changes destination;
reselecting the active destination never opens help. Guided destination titles
open a compact dropdown with Help as the first option; Browse keeps Help above
Dictionary and saved-page choices in that same title menu so help remains
discoverable without interfering with tab navigation.
Each destination guide should name concrete user actions and examples, not merely
summarize the section.
Every guide uses `Why it matters` followed by `What you can do`; AI Link is
specifically framed as extending beyond traditional dictionary coverage through
contextual translation, deeper explanation, emerging concepts, and phrase extraction.
That purpose-first framing is shared by the AI Link screen, welcome guidance,
task descriptions, Browse extraction/translation sheets, and glossary; describe
the learner outcome before copy/paste, API, or other implementation mechanics.
Keep glossary coverage current with user-visible learning objects and workflows,
including sentence-level practice, favorite sentences, practice packs, page AI
tasks, and private API-key automation. Glossary entries should pair terms with
the icons users see in the app whenever an SF Symbol can make the reference more
recognizable. `RadixGlossaryIcon` is the canonical mapping for glossary/help term
icons and matching in-app labels; use it instead of scattering per-view
term-to-symbol switches. Prefer `RadixTermLabel` for visible labels tied to
glossary terms, and `RadixHelpLabel` for ordinary Help menu rows. The glossary
now includes the page-first Study model, page artifacts, sentence database,
sentence examples, Manual AI Link, Gemini API, page AI tasks, Quiz, Extract
Sentences, and Create Conversation.
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
Study saved-page AI actions are grouped by task—Check OCR, Extract Phrases,
Translate Page, Create Quiz, Extract Sentences, Sentence Practice, and Create
Conversation.
Current UI copy uses `Create Conversation`; older labels such as `Create
Practice from Page` are compatibility aliases only.
Each task consistently offers copy/paste with ChatGPT or an automatic Gemini
route where automation is implemented. A missing-key automatic choice becomes
`Set Up Gemini API Key…`, navigates to Settings where `Automatic AI` exposes
Gemini setup, and preserves the contextual return path. Setup is described as
enabling all page AI automation, not just one task. Study page actions declare AI tasks
through a shared task model with one manual action and one automatic action.
Manual copy/paste page AI actions open the matching AI Link task with the saved
page selected and preserve the contextual return path; automatic Gemini actions
must use the same store-level prompt/result helpers.
Do not add task-specific menu plumbing or separate paste sheets for new page AI
actions.
These tasks also exist as editable saved-page templates in AI Link. Browse OCR
review renders the `Check OCR` template with saved page characters,
recognized/unrecognized characters, and nearby phrase evidence rather than a
separate hard-coded instruction. Legacy `Check OCR` templates that described
`ORIGINAL OCR` normalize to the saved-page-character wording so placeholder raw
OCR cannot become the primary AI input.
`Extract Sentences` is the close-to-source page transformation task: it asks AI
to produce cleaned Chinese page prose plus sentence records with Chinese, pinyin,
English, and phrase hints. The result is saved as a page-owned extracted
sentence artifact and upserted into the shared sentence database.
`Sentence Practice` is the drillable practice-pack task: it asks AI to return
the same lightweight Conversation Practice import JSON shape (`theme` plus
`entries`) used by generated practice packs, so imported page sentences reuse
the existing practice, favorite-sentence, backup, checkpoint, and speech
pathways instead of creating another sentence store. The automatic Gemini route
validates and imports that pack directly. AI Link exposes one `Sentence
Practice` task with a `Brief` / `Detailed` detail selector instead of separate
sentence-practice tasks; both modes must return the same import JSON and land in
the shared sentence database.
`Create Conversation` is distinct from `Sentence Practice`: it uses the
saved page as source inspiration, infers the page's broad conversational theme,
and asks AI to generate new personalized/current Conversation Practice lines
around that theme rather than staying close to the page wording. It returns the
same lightweight Practice JSON shape and imports through the same shared path.
AI-generated Conversation Practice sentences should be concise and complete, but
there is no hard total-character limit; the sidebar handles longer sentences by
inspecting them as navigable four-character animation groups. When a Practice
sentence card is open, the sidebar does not repeat the sentence and pinyin that
are already visible in the main Practice list.
Phrase info cards keep explicit previous/next controls beside the character
group counter and scroll the group chips to the selected group, so every
four-character animation page remains reachable even when the chip row overflows
in the sidebar.
The page-sentence AI template instructs AI to set the import `theme` exactly to
the source page title. Pages uses that same-name convention to show a page-row
Practice shortcut. Do not add a full source-metadata schema yet; if
title matching becomes unreliable, revisit a `Practice Source Link` model with
source kind, stable source ID when available, source title/date, and a content
fingerprint fallback.
Conversation Practice accepts AI-generated packs through `Paste Practice JSON`
as the primary return path from ChatGPT/Gemini, while `Import JSON File` remains
available for saved files and transfer. The paste route previews the theme,
sentence count, sample sentences, and validation warnings before import.
Pages `Actions` exposes `Sentence Practice` as a page AI task. Manual use
copies/opens the saved-page sentence-practice prompt and returns through Study's
Conversation Practice paste importer; automatic Gemini use imports the pack
directly.
When an imported Conversation Practice pack title matches the selected saved
page title, Pages shows a compact practice shortcut in that saved-page row,
beside the delete control. Tapping it opens Study directly into that matching
Conversation Practice theme.
AI Link exposes one task per user goal. The former API-only phrase task is
removed; `Extract Phrases` supports both copy/paste and automatic Gemini
execution without appearing twice.
`Extract Phrases` should optimize for dictionary-quality results over count:
reject noisy adjacent-character groupings, trim unrelated leading/trailing
characters such as the leading `进` in `进青瓦屋`, and label proper names as
person/place/organization/work names in the English meaning instead of giving
vague glosses. Older saved phrase-extraction templates normalize to this stricter
boundary/meaning wording.
AI Link is the complete manual AI round trip: after opening/copying a prompt,
task-specific result paste/apply controls live in AI Link for OCR correction,
phrase extraction, translation reports, and Conversation Practice imports. The
prompt template editor is collapsed by default so task, source, send, and result
remain the primary workflow. The `Paste AI Answer` action row stays above the pasted
answer, pasted text is height-limited and collapsible, and successful imports
auto-collapse long result text so follow-up actions remain visible.
After AI Link imports a Conversation Practice pack, the success state offers a
direct `Open in Study` action. It opens Study to the imported practice set and
uses the existing contextual return path so the focused Practice screen shows
`Back to AI Link`.
Manual paste results and automatic Gemini results share store-level application
helpers for phrase imports, OCR correction, translation reports, and Conversation
Practice imports; UI layers should only choose presentation, source selection,
and follow-up navigation. When phrase extraction runs from a saved page, Radix
records all extracted non-base phrase words against that page, not just newly
inserted phrases, so the Study saved page row can show a `Phrases` artifact chip
and list the page-derived user phrase set later.
The AI Link tab presents one task at a time through an `AI Task` dropdown. The
old `Instructions`/`Customize` split is collapsed into a single editable
`AI Prompt` template for the selected task. Built-in tasks edit the prompt
template without repeating the task title in a second title field; custom tasks
also show a task-name field. Prompt edits are draft-only until the user taps
`Save`; `Undo` restores the built-in default for shipped tasks or the starter
prompt for custom tasks and shows a compact next-row confirmation that editing
can continue. Custom tasks carry an explicit subject type: `Character / Phrase`,
`Sentence`, or `Page`. The selected subject type controls the source row, prompt
validation, and rendering placeholders; built-in page/theme task subject types
remain fixed so result import flows stay predictable. Sentence custom tasks use
the active sentence card as their source and can render `{sentence_zh}`,
`{sentence_en}`, `{sentence_pinyin}`, `{sentence_phrases}`, and
`{sentence_characters}`. The task menu includes `New AI Task...`. AI Link does not show a
full generated prompt preview or a separate
ready-to-send summary; the selected task appears on the primary open button
(`Open Gemini: Task 2`) instead. Do not reintroduce a separate prompt-context
line because the task row and source selector already own subject/page/topic
context. The active task selector and source selector rows share compact
menu-card styling. The source selector and open controls appear immediately
after the AI task menu, before the editable prompt, so the user can confirm the
page/subject and send without scrolling through the template first.
Opening the selected AI copies the prompt first, then opens the AI provider;
copy-only remains available from the provider menu. Launch/copy status notices
sit on their own row below the open controls rather than sharing the button row.
The live prompt editor edits the selected task inline. The bulk AI Templates
manager is reachable from the AI Link toolbar and remains out of the primary
workflow; use it for global character/page prompt closings, adding or deleting
custom prompt tasks, and editing all templates in one place.
Character and phrase tasks default to the most recent memory-strip subject, and
the subject row itself is a dropdown of recent memory-strip items rather than a
Search shortcut. Page tasks default to the last viewed saved page while still
showing the chosen source so the user can change it before sending.
The `Generate Practice Pack` topic menu includes the four bundled Practice
topics plus generation-ready broad themes: Everyday Conversation, Food &
Shopping, Travel & Transportation, Home & Personal Life, Work & School, Health
& Emergencies, City Life & Services, Social & Culture, Technology & Modern Life,
and Opinions & Deeper Talk. Keep these as broad choices in the AI tab rather
than expanding them into a long flat menu of narrow situations.
The `Generate Practice Pack` template asks the user's chosen AI app to tailor
conversation packs from the selected theme using available chat context,
learner circumstances, and current or popular topics when the AI app can browse
or use current knowledge. Radix should keep the output contract strict
(`theme` plus `entries[]` with `id`, `zh`, `pinyin`, and `en`) without adding
extra content guardrails beyond import format and language-learning usefulness.
AI Link exposes a shared quantity selector for Conversation Practice output
tasks, defaulting to 25 entries with 50 and 100 available. `Generate Practice
Pack`, `Sentence Practice`, and `Create Conversation` render this shared
count through `{conversation_entry_count}`; future sentence/conversation
generation tasks should opt into `conversationEntryCountTaskIDs` and reuse the
same placeholder instead of hardcoding a pack size.
The `Sentence Practice` Brief/Detailed selector is a profile preference saved
with local AI Link settings and portable backups; restore falls back to Brief
when importing older profiles.
OCR correction no longer has a proposal-approval screen. Automatic Gemini
review creates and opens the corrected page in Pages; copy/paste uses
one `Paste Answer and Create Corrected Page` action. The original OCR page is
retained as the reversible source record until the user promotes a corrected
page from Study, where the original can either be kept as an archived page or
discarded.
Corrected pages retain the longest possible prefix of the original 11-character
name and add a unique numeric suffix such as `1` or `2`.
The corrected source remains Chinese, while change reasons, confidence, and
uncertainty explanations are explicitly requested in English.
The Study tab remains the user's main review surface. Its dashboard controls
separate `Recent` and `Favorites` as mutually exclusive grid scopes from focused
sections such as Added Phrases, Conversation Practices, Sentences, and iPhone
Checkpoints. Favorite Sentences is represented within Conversation Practices,
not as a separate dashboard shortcut. The Conversation Practices shortcut
defaults to the `Favorite Sentences` topic when favorite sentences exist. Saved
pages open through Browse for tile inspection, with explicit page Study actions
for page learning. Added Phrases opens as a full Study workspace rather than a
pop-out sheet, with a visible `Back to Study` control and no global Study
header competing for space. Conversation Practices opens a focused Practice
screen with a contextual return button. It says `Back to Study` from Study and
`Back to Browse` when a Browse-origin page shortcut opened the practice. There is no
persistent `Review | Practice` switch row. Recent and Favorites must not be
repeated as another segmented picker above the review grid.
Conversation Practice is the next Study learning section. It presents curated
practice sets such as `General Greetings`, `Restaurants`, `Airport`, and
`Shopping Mall`, starting with about 100 common beginner conversational
sentences in Simplified Chinese with pinyin and English. These lessons must
tightly reuse Radix's Character/Phrase dictionary infrastructure: each sentence
is a Phrase DB-backed practice item, tapping a lesson sentence opens the normal
Phrase card or Browse inspection, and detected characters/sub-phrases should
lead to existing Character and Phrase cards. Any phrase or character selected
inside Practice is also pushed into the shared memory strip/recent Study state,
so Practice feeds the same review and AI subject workflows as the rest of
Radix. Practice sets add ordering, difficulty, scenario grouping, and progress;
they are not a parallel phrasebook database. Keep curated lesson progress
separate from Added Phrases classification so users are not asked to
accept/reject shipped lesson content.
Conversation Practice topics are selected through a Study dropdown. `General
Greetings` remains the first/default topic backed by `conversation100.json`.
`Food / Eating Conversation` is the second configured topic, backed by the
bundled `Food Dining.json` pack for restaurant, hawker/casual eatery, and home
dinner-table practice content. `Trip to 4 Cities` is the third configured topic,
backed by `Trip to 4 cities.json` for Beijing, Shanghai, Guangzhou, and Taipei
travel situations. `Stay in Shanghai` is the fourth configured topic, backed by
`Stay in Shanghai.json` for longer-stay study, housing, utilities, transport,
local services, and administrative tasks. Topic configuration must remain
data-driven so future topics can be added without rebuilding the Study UI.
Imported Conversation Practice packs persist through the same backup and
checkpoint flows as the rest of Study. My Data's backup preview lists Practice
as its own saved section, including the selected topic, bundled topic count,
and imported practice-pack sentence counts.
Checkpoint or backup returns must refresh Study's imported Practice cache
immediately after restore so deleted imported packs reappear without requiring
the Study tab to be recreated.
The AI Link generator task emits the lightweight importable Practice JSON shape
`{ "theme": "...", "entries": [{ "id", "zh", "pinyin", "en" }] }`, so AI
content can be saved as a file, imported from the Study dropdown, validated by
`ConversationPracticeRules`, and turned into a Phrase-backed practice set.
`ConversationPracticePack` also accepts simplified uploaded packs that contain
pack identity plus `entries[].id`, `category`, and `sentence`; the decoder fills
safe defaults for source metadata, sequence, level, analysis, metadata, and
notes before validation. The Study Conversation Practice dropdown includes an
`Import Practice JSON` action. Imported packs are validated, persisted in
preferences under `RadixPreferenceKey.importedConversationPracticePacks`, added
to the topic dropdown, selected immediately, and registered with the same
Practice phrase cache as bundled topics. If an import would replace an existing
imported pack or override a bundled topic by using the same pack ID, Radix first
shows a compact replacement confirmation with current/new sentence counts and
validation-warning count. User/imported files may also use the lightweight
AI-friendly shape `{ "theme": "...", "entries": [{ "id", "zh", "pinyin",
"en" }] }`; Radix derives the pack ID, title, category, analysis, and metadata
before validation. Imported Practice packs are also part of `UnifiedPackage`, so
normal backup files and local checkpoints save and restore them across devices.
The first useful practice modes should be simple offline drills such as
Flashcards and Quick Quiz, with answer feedback linking back into Phrase and
Character cards rather than dead-ending in a quiz-only screen. The detailed
implementation state is current in the bullets below; do not recreate separate
plan/status files for completed phases.
`conversation100.json`, `Food Dining.json`, `Trip to 4 cities.json`, and
`Stay in Shanghai.json` are bundled topics loaded through
`ConversationPracticeService`. `ConversationPracticePack` and
`ConversationPracticeRules` define the portable JSON contract, mapping,
ordering, duplicate checks, and validation gate for bundled, uploaded, or
AI-generated packs. Validated packs produce a `ConversationPracticeLibrary`
with display items, Phrase DB seed rows, and stable practice-set memberships.
Sentence punctuation is preserved for display but trimmed from phrase keys so
sentences can resolve to Radix phrase records.
Conversation Practice appears in Study as a focused practice workspace.
Imported topics are removable; bundled topics are fixed. The selected topic
name appears once in the topic picker rather than repeating in a nearby header.
Flashcards show Chinese first, reveal pinyin/English, record Again/Good/Easy
responses to portable Practice progress, and keep Phrase/Character inspection
inside the active sheet. Quick Quiz is an offline single-character recognition
sheet that blanks one character, uses script-aware confusable/component peers
with dictionary fallbacks, records correct/incorrect attempts, and keeps
feedback linked to Radix Phrase and Character cards. Flashcards and Quick Quiz
are compact tools, not persistent bottom buttons. The old local Translate Quiz
has been removed because translation practice should be AI-backed. Sentence browsing is
embedded directly in the Study Practice card with compact page controls, a
Chinese/English display toggle, visible selected-row state, and the normal
Study information-card path for richer inspection. Only Conversation Practice
sentence cards repurpose the sidebar `Phrase` action to show phrases verified
inside that sentence; all other information-card contexts keep normal broad
phrase lookup behavior.
The Conversation Practice Simplified/Traditional choice is shared across the
Practice card, Flashcards, and Quick Quiz, including displayed sentences, drill
hint chips, character links, and opened Phrase card titles.
Shared script-support helpers own Practice phrase-card conversion and
character-chip filtering so drill modes follow the same coverage rules. Phrase
hint chips in Practice drills are database-verified only, display longest-first,
and appear before character chips; character chips omit any characters already
covered by displayed phrases. Curated or detected groupings must resolve exactly
in the bundled base phrase database or the additional phrase database before
display. Practice must not show inferred adjacent-character groupings or
placeholder phrase cards such as `No meaning saved`; unmatched sequences fall
back to individual character links or smaller exact phrase matches.
Flashcards and Quick Quiz open those Phrase and Character cards inside their
own navigation stacks, so Back returns to the practice mode instead of ejecting
the user from the lesson flow. The embedded Study card list opens Phrase and
Character cards through the normal Study information-card path; users return to
a sentence card by clicking the highlighted sentence row again rather than
through extra sidebar back or clear controls. Phone information previews omit
extra `Study`/`Browse` shortcut buttons in this flow, and the sentence return
action from a character preview is labelled `Sentence`. On iPhone, a Practice
sentence card itself shows a compact `Sentences` return action so the expanded
sentence list is reachable without adding generic Browse/Study shortcuts.
Character links use the normal full `CharacterDetailView`, not the lightweight
preview card. Drill-sheet character inspection must not set the global
`previewCharacter`, because dismissing Flashcards or Quick Quiz should return
to the focused Practice screen rather than switching the phone Study surface to
the character preview.
The focused Conversation Practice screen hides the generic Study description
and section title. A compact control area directly above the sentence list combines
previous/next page controls, the visible row range, script choice, and the
Chinese/English display toggle, so users page through lesson rows instead of
scrolling a 100-sentence list. On narrow phone layouts, that control area may
split into two compact rows to avoid crowding the range label and language
toggles. Flashcards and Quick Quiz belong in the compact tools menu instead of
a pinned bottom bar. Imported topic deletion is an icon action beside the topic
picker, not a full-width row.
Practice sentence read-aloud uses the existing Radix speech infrastructure and
the shared Chinese voice. Flashcards and Quick Quiz show compact speaker controls
beside the active sentence; Flashcards also read the sentence, phrase, or
character when opening the Phrase Card, phrase chips, or character chips into
their information cards. The expanded sentence list continues to open and read
the normal Phrase-backed sentence card rather than adding a speaker control to
every row.
Practice progress is a portable `ConversationPracticeProgressSnapshot` keyed by
pack/item ID. Flashcards record Again/Good/Easy responses, Quick Quiz records
correct/incorrect attempts, and only Good/Easy/correct outcomes count an item
complete. Progress is persisted under `RadixPreferenceKey.conversationPracticeProgress`
and included in `UnifiedPackage` backup/checkpoint flows. The focused Practice
topic subtitle shows per-topic completion and last-practiced state without
adding a separate explanation row. Flashcards and Quick Quiz are the only local
Practice drills; local Translate Quiz was removed so translation practice can
return later through AI-backed workflows instead of another offline drill.
Practice linked phrase/character hints are cached in
`RadixStoreConversationPractice` per practice item and invalidated when Practice
phrase libraries register or phrase-backed Study data refreshes, so drill sheets
do not repeatedly rediscover the same hints during SwiftUI redraws.
`CharacterDetailView` no longer embeds the old Breakdown/Derivatives lineage
grid; structure exploration remains available through the dedicated Character
Breakdown explorer instead of crowding the info card.
Added Phrases review is phrase-first: no search field, no persistent help text,
and no visible AI shortcut above the grid. The top row shows the status filter,
an `Actions` menu, and `Back to Study` when it is opened as the Study
workspace; the reusable modal wrapper may still show `Done` where a sheet is
explicitly needed. `Actions` includes `Create AI Review Page` for current
unreviewed phrases, bulk status/deletion actions, and help. The AI Review
action creates a saved page from all current unreviewed, non-base added
phrases, then opens that page in Pages.
This action does not mark, accept, reject, or delete the source phrases. Review
phrases sort by pinyin, and pagination uses the visible pinyin letter range
such as `b-c`; when more than one page exists, that range label opens a direct
page-jump menu. The review uses a paged non-scrolling grid whose page size is
calculated from the measured vertical space above the footer; fixed platform
counts are only first-render fallbacks. Bulk painting preserves the active
filter while a status tool is selected so large unreviewed queues shrink in
place instead of jumping to the phrase's new status bucket. Selecting a phrase
for preview uses the shared Phrase Info Card route in the sidebar, matching
Browse and Search; larger layouts should not also show a duplicate compact
phrase preview row inside the review workspace. Status tools keep readable
words and icons rather than becoming icon-only.
The eligibility, ordering, page name, page-range label, and newline-delimited
source text are portable `AddedPhraseReviewRules` behavior with compatibility
tests so Android can share the same rule.
Content-driven cross-tab navigation uses the existing single-level return
context. Destinations show a named return button (`Back to Browse`, `Back to
Study`, `Back to My Data`, and so on); manually choosing a primary tab clears
that context. Browse uses one labelled `Actions` menu for editing, OCR review,
phrase selection, translation, and AI workflows. The title menu remains the
Dictionary/saved-page navigation; only the character count, script toggle, page
actions, explicit Study shortcut, and Read Aloud remain permanently visible
page controls.
Camera/capture owns source actions such as text from the clipboard, image from
the clipboard, image from Album, and image from Files. Clipboard images use the
same OCR page creation path as camera, album, and file images.
Entering Browse selects the saved page with the newest viewed-or-created date;
the same selection is established during startup because the app launches on
Browse without invoking a tab transition. Dictionary is the fallback only when
no saved pages exist.
Saved-page name normalization, corrected-name suffixing, and most-recent
selection live in portable `SavedPageRules` with compatibility tests. SwiftUI
only supplies actions; one shared Browse gateway handles missing Gemini keys
for OCR, phrase extraction, and translation. Page quiz generation is an AI Link
chat-prompt workflow rather than a local quiz-generation/import path.
The OCR, extraction, and translation task menus share the same method vocabulary:
`Use Another AI App` or `Run Automatically in Radix`. The first method choice
shows one concise orientation, then continues the chosen action; `How Radix Uses
AI` reopens it without adding permanent screen text. The orientation uses a
sheet with pinned actions on every platform so iPad cannot truncate the
description or lose the continuation control.
Copy-and-paste is the durable fallback and remains visible even when a Gemini
key is saved. Automatic OCR, extraction, or translation failures offer a clear
fallback because a valid key does not guarantee Gemini service availability.
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
Create Quiz is page-only and uses the AI Link saved-page task rather than a
local Radix quiz screen. The Study page `Quiz` chip opens the editable quiz
template in AI Link with the page selected, allowing the user to continue in
ChatGPT, Gemini, or another AI chat. The default prompt asks the AI to draw from
the user's learning themes instead of staying limited to one page's exact
characters; it defaults to Simplified Chinese and HSK 4, rotates varied
assessment styles, keeps answer choices Chinese-only, keeps pinyin out until
after the learner answers, and requires English translations that do not leak
the answer. It must explicitly assign the AI as quizmaster and the human user
as learner, use the required one-question format, then stop after Question 1
without revealing answers, analysis, pinyin, explanations, or Question 2 until
the learner replies. Radix does not import a quiz result and must not offer a
local dictionary-backed fallback quiz for this page task. The AI Link route
preserves the appropriate return action such as `Back to Study` instead of
leaving the user to find their way back manually.
Navigation guidance and the welcome screen use one canonical division of work:
Browse inspects the dictionary or captured pages; Study reviews what the user
kept; AI understands or transforms material; My Data protects, transfers, or
exports the user's work.
The global capture action is labelled `Camera` across iPhone, iPad, and Mac;
avoid reverting to `Take Photo` in visible navigation. That action should feel
fast by opening the camera sheet immediately, but it must leave the normal
capture workbench underneath so dismissing the sheet reveals the other capture
sources instead of a Camera-only dead end. The global Search/Camera tiles are
shared through `GlobalSearchCameraActionRow` and RootView's
`openSearchFromGlobalAction` / `openCameraFromGlobalAction`; do not clone those
buttons separately for phone and sidebar layouts.
Local snapshots are presented as `Checkpoints` to avoid colliding with backup
language. On iPad and Mac, Checkpoints live in the sidebar when no
character/phrase information card is displayed; the section disappears while an
information card owns the sidebar focus. Top-level navigation and global
non-character/non-phrase actions clear the information card so Checkpoints
return to the sidebar once that contextual focus is no longer active. On iPhone,
where there is no persistent sidebar, Checkpoints are the seventh icon in the
top Study scope row and open a sheet with one Create Checkpoint action and the
full retained checkpoint list, up to `LocalDataSnapshotStore.maximumSnapshotCount`.
Keep the Study Checkpoints section rendering in `FavouritesCheckpoints.swift`
rather than growing `FavouritesSections.swift`.
The iPad/Mac sidebar remains a compact recent-checkpoint preview and should
label that subset when more checkpoints exist. Tapping a row is the return
action after confirmation, so there is no separate restore menu competing with
the learning content. Returning to a checkpoint always leaves the user in Study,
even if the checkpoint was created while another tab was active. iPhone Study
includes a compact `Backup files` bridge to My Data so users can still
distinguish local learning recovery from portable file protection.
My Data’s `Backup File` screen owns Backup File actions only. Backup
history stores lightweight file metadata and shows filenames; a selected backup
file merges or restores immediately when the saved path is still readable,
otherwise Radix falls back to the file picker with the chosen Merge/Restore
intent preserved. My Data links back to Study for Checkpoints instead of
duplicating the checkpoint controls; this is a compact `Checkpoints` button,
not explanatory checkpoint copy.
Backup File actions keep the same three choices across iPhone, iPad, and Mac:
Create Backup, Merge Backup, and Restore Backup. Create means create a new file
from this device; Merge means combine the backup file and this device so both
contain the merged contents; Restore means replace this device with the file.
Checkpoint means save the current state as a same-device recovery checkpoint.
All platforms stack the actions with
Create Backup, then primary Merge Backup, then destructive Restore Backup.
My Data content is width-capped inside its column so long explanations and
action cards do not visually spill to the screen edge.

## Current Engineering Posture

The remaining `RadixStore` content is legitimate state ownership, caches,
dependencies, and compatibility plumbing. Repository protocols are not being
added until a concrete alternate repository implementation needs them.

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
- When Xcode reports missing files, first distinguish stale project references
  from real source loss; the app target should include the actual Swift files
  under `App`, `Models`, `Services`, `ViewModels`, `Views`, and `Shared`.
- For broad UI polish, add or extend shared visual primitives first, then adopt
  them in focused surfaces so style changes remain reviewable and reversible.

## Required Verification

For normal model/store refactors:

1. `git diff --check`
2. Portable Swift package tests
3. Mac Catalyst build with code signing disabled

Before a release or after platform-sensitive UI/data changes, also build the
generic iOS target, which covers the universal iPhone/iPad application. Simulator
launch failures caused by CoreSimulatorService are environmental and should be
reported separately from compilation failures.

## Updating This File

At the end of each completed work unit:

1. Update architecture statements affected by the change.
2. Replace the active workstream and next tasks when priorities move.
3. Add only significant milestones; do not append a verbose session diary.
4. Update test counts and verification expectations when they change.
5. Commit this file with the code it describes.
