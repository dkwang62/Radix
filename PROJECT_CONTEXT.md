# Radix Project Context

This is the concise engineering hand-off and current source of truth for ongoing
Radix work. Read it before changing the project. Update it in the same commit as
each completed work unit. Git remains the detailed historical record; this file
describes the present state and immediate direction.

Last reviewed: 2026-07-03

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
- Curated Study lesson sentences must be Phrase DB-backed, or referenced by a
  practice-set layer that points to Phrase DB records. Do not build a separate
  lesson-only Chinese sentence store that bypasses Radix Phrase cards,
  Character cards, favorites, notes, Browse inspection, or review state.
- Study-owned favorite sentences are persisted as `FavoriteSentenceRecord`
  snapshots and exposed as a generated `Favorite Sentences` Conversation
  Practice library, so sentence review uses the same flashcard, quiz, translate,
  speech, backup, and checkpoint pathways as other practice sets.
  Sentence info cards pass an explicit `.sentence` favorite target, while
  ordinary phrase cards use `.phrase`, so the star cannot silently switch
  between character, phrase, and sentence semantics. Conversation Practice
  sentence preview cards also expose an explicit read-aloud button for the full
  sentence. On iPhone, the preview return button names the active Conversation
  Practice theme rather than a generic sentence list. Phrase and sentence
  preview cards show the meaning text directly, and character preview cards show
  the definition directly, without redundant section headings.
- Portable backup: `UnifiedPackage` schema 5, with legacy backup decoding retained.
- Bundled standard data imports additively once on startup from
  `radix_unified_backup.json`, guarded by `RadixPreferenceKey.standardDataImportID`.
- `RadixPreferenceKey` is the canonical list of stable persisted identifiers.
- `RadixPreferenceStore` is the platform-neutral storage boundary.
- Apple persistence uses `RadixPreferences`, backed by `UserDefaults`.
- `RadixStore`, `EntitlementManager`, and the phrase database location manager
  accept an injected preference store.
- On iPhone, character or phrase previews opened from a saved Browse page show a
  contextual return button named for that page, not a generic Browse label.
- In Browse, the top `Browse [page name]` navigation title is the quick
  saved-page selector for Dictionary and saved pages. The open-page card still
  keeps its source button because that opens the full source/import panel, but
  the card does not repeat the page name and keeps that source button in the
  local control row.

Never change an existing preference key, enum raw value, backup field, or review
status without an explicit migration and compatibility test.

### Portable core

`Package.swift` defines `RadixCore`, which contains platform-neutral models and
compatibility contracts. Current portable contracts include:

- backup and profile models/codecs
- phrase-review status behavior
- navigation, tab, script-filter, and restore-mode identifiers
- preference keys and the preference-storage interface

The portable test suite currently contains 44 tests across eight suites.

## Active Workstream

The central-store maintainability refactor is complete. Current product work is
restoring unobtrusive navigation guidance: optional labels plus first-use,
dismissible destination explanations that experienced users can hide or replay.
Before changing any screen, apply `UI_INTENT.md`'s Design decision rules:
preserve visible return paths, fight for content space, and remove duplicate
meaning before adding new labels, rows, switches, or cards. Balance those rules
with the documented guardrails for orientation, discoverability, breathing room,
accessibility, and visible state changes.
App-wide inline alerts, notices, and status messages should appear on the next
row below their related controls, not beside them. This keeps action rows from
being squeezed and makes the message read as feedback rather than another
control.
Navigation help presentation belongs at `RootView`; do not attach popover or
context-menu presentation containers to the five equal-width tab buttons because
those wrappers can collapse the SwiftUI HStack to one visible destination.
On iPhone, iPad, and Mac Catalyst, ordinary navigation only changes destination;
help opens only after selecting the same active destination twice in a row so it
never obscures routine navigation.
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
Translate Page, Create Quiz, Extract Sentences, and Create Practice from Page.
Each task consistently offers copy/paste with ChatGPT or an automatic Gemini
route where automation is implemented. A missing-key automatic choice becomes
`Set Up Gemini API Key…`, navigates to Settings with Private API Keys expanded,
and preserves `Back to Browse`. Setup is described as enabling all page AI
automation, not just one task. Browse page actions declare AI tasks through a
shared task model with one manual action and one automatic action. Manual
copy/paste page AI actions open the matching AI Link task with the saved page
selected and preserve `Back to Browse`; automatic Gemini actions may stay in the
Browse page workflow but must use the same store-level prompt/result helpers.
Do not add task-specific menu plumbing or separate paste sheets for new page AI
actions.
These tasks also exist as editable saved-page templates in AI Link. Browse OCR
review renders the `Check OCR` template with saved page characters,
recognized/unrecognized characters, and nearby phrase evidence rather than a
separate hard-coded instruction. Legacy `Check OCR` templates that described
`ORIGINAL OCR` normalize to the saved-page-character wording so placeholder raw
OCR cannot become the primary AI input.
`Extract Sentences` is the first step toward page-derived sentence study:
it asks AI to return the same lightweight Conversation Practice import JSON
shape (`theme` plus `entries`) used by generated practice packs, so imported
page sentences reuse the existing practice, favorite-sentence, backup,
checkpoint, and speech pathways instead of creating another sentence store. The
automatic Gemini route validates and imports that pack directly.
`Create Practice from Page` is distinct from `Extract Sentences`: it uses the
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
the source page title. Browse currently uses that same-name convention to show a
page-row Practice shortcut. Do not add a full source-metadata schema yet; if
title matching becomes unreliable, revisit a `Practice Source Link` model with
source kind, stable source ID when available, source title/date, and a content
fingerprint fallback.
Conversation Practice accepts AI-generated packs through `Paste Practice JSON`
as the primary return path from ChatGPT/Gemini, while `Import JSON File` remains
available for saved files and transfer. The paste route previews the theme,
sentence count, sample sentences, and validation warnings before import.
Browse page Actions exposes `Extract Sentences` as a page AI task. Manual use
copies/opens the saved-page sentence extraction prompt and returns through
Study's Conversation Practice paste importer; automatic Gemini use imports the
pack directly.
When an imported Conversation Practice pack title matches the selected saved
page title, Browse shows a compact practice shortcut in that saved-page row,
beside the delete control. Tapping it opens Study directly into that matching
Conversation Practice theme.
AI Link exposes one task per user goal. The former API-only phrase task is
removed; `Extract Phrases` supports both copy/paste and automatic Gemini
execution without appearing twice.
AI Link is the complete manual AI round trip: after opening/copying a prompt,
task-specific result paste/apply controls live in AI Link for OCR correction,
phrase extraction, translation reports, and Conversation Practice imports. The
prompt template editor is collapsed by default so task, source, send, and result
remain the primary workflow. The AI Result action row stays above the pasted
answer, pasted text is height-limited and collapsible, and successful imports
auto-collapse long result text so follow-up actions remain visible.
After AI Link imports a Conversation Practice pack, the success state offers a
direct `Study Practice` action. It opens Study to the imported practice set and
uses the existing contextual return path so the focused Practice screen shows
`Back to AI Link`.
Manual paste results and automatic Gemini results share store-level application
helpers for phrase imports, OCR correction, translation reports, and Conversation
Practice imports; UI layers should only choose presentation, source selection,
and follow-up navigation.
The AI Link tab presents one task at a time through an `AI Task` dropdown. The
old `Instructions`/`Customize` split is collapsed into a single editable
`AI Prompt` template for the selected task. Built-in tasks edit the prompt
template without repeating the task title in a second title field; custom tasks
also show a task-name field. Prompt edits are draft-only until the user taps
`Save`; `Undo` restores the built-in default for shipped tasks or the starter
prompt for custom tasks and shows a compact next-row confirmation that editing
can continue. The task menu includes `New AI Task...`. AI Link does not show a
full generated prompt preview or a separate
ready-to-send summary; the selected task appears on the primary open button
(`Open Gemini: Task 2`) instead. The source selector and open controls appear
immediately after the AI task menu, before the editable prompt, so the user can
confirm the page/subject and send without scrolling through the template first.
Opening the selected AI copies the prompt first, then opens the AI provider;
copy-only remains available from the provider menu. Launch/copy status notices
sit on their own row below the open controls rather than sharing the button row.
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
Pack`, `Extract Sentences`, and `Create Practice from Page` render this shared
count through `{conversation_entry_count}`; future sentence/conversation
generation tasks should opt into `conversationEntryCountTaskIDs` and reuse the
same placeholder instead of hardcoding a pack size.
OCR correction no longer has a proposal-approval screen. Automatic Gemini
review creates and opens the corrected Browse page immediately; copy/paste uses
one `Paste Answer and Create Corrected Page` action. The original OCR page is
always retained as the reversible source record.
Corrected pages retain the longest possible prefix of the original 11-character
name and add a unique numeric suffix such as `1` or `2`.
The corrected source remains Chinese, while change reasons, confidence, and
uncertainty explanations are explicitly requested in English.
The Study tab remains the user's main review surface. Its summary grid includes
`Conversation Practices` beside Recent, Favorites, Added Phrases, and Saved
Pages; the tile shows the available theme count and opens a focused Practice
screen with a contextual return button. It says `Back to Study` from Study and
`Back to Browse` when a Browse page shortcut opened the practice. There is no
persistent `Review | Practice` switch row. Recent and Favorites must not be repeated as a
segmented picker above the review grid.
On iPad and Mac Catalyst those four tiles use an explicit two-column layout so
all labels remain readable; phone keeps its adaptive layout.
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
implementation plan and current Practice roadmap are
`CONVERSATION_PRACTICE_PLAN.md`; use it before building content import, data
models, progress tracking, or Study UI for this feature.
Step 1 of that plan is now in place: `conversation100.json` is the starter
content, and `ConversationPracticePack` plus `ConversationPracticeRules` define
the portable JSON contract, mapping, ordering, duplicate checks, and validation
gate for uploaded or AI-generated lesson packs.
Step 2 has the first Phrase-backed mapping layer: validated packs now produce a
`ConversationPracticeLibrary` with display items, Phrase DB seed rows, and
stable practice-set memberships. Sentence punctuation is preserved for display
but trimmed from the phrase key so `你好。` resolves to the Radix phrase `你好`.
`ConversationPracticeService` loads and validates the bundled starter pack for
the future Study UI.
Step 3 has a first Study entry point: `Conversation Practice` appears in Study
when the starter pack loads, showing the `General Greetings` set count and a
small set of sample sentences. Those samples resolve through the existing Phrase
card presentation path, preserving the Radix dictionary connection.
Imported practice topics can be removed from the same Study section with a
dedicated delete control; bundled starter topics remain fixed.
The selected Practice topic name should appear once in the topic picker rather
than being repeated again in the card header beneath it.
Step 4 has the first `Flashcards` flow: the starter set opens a card sheet
that shows Chinese first, reveals pinyin/English, records Again/Good/Easy
responses to portable Practice progress, and links the full sentence, detected
phrase hints, and character hints back into existing Phrase and Character card
presentation.
Step 5 has the first `Quick Quiz` flow: the starter set opens an offline
single-character recognition sheet that blanks one character inside the source
sentence. Each run samples up to 20 practice items in random order, shuffles the
displayed options for each round, and includes a Simplified/Traditional control;
the blanked sentence, answer options, feedback character, phrase card word, and
character links follow the shared Study Practice script choice. Quick Quiz
prioritizes characters with strong visually confusable peers and uses
deterministic portable answer-choice rules that prefer similar-looking full
characters rather than radicals. `ComponentRepository` maintains a cached,
script-filtered confusability index built from meaningful decomposition overlap;
generic stroke/radical-only overlap is treated as low signal. Feedback shows
pinyin/meaning, score for the session, and links back to the existing Phrase and
Character card presentation. Quiz results record correct/incorrect attempts to
portable Practice progress. Quick Quiz caches the selected round plus
per-character peer/candidate lookups so SwiftUI redraws do not rebuild choices.
If the strict confusability index cannot supply enough distractors, Quick Quiz
falls back through broader shared-component, related-character, and
script-matched dictionary choices rather than showing a one-choice round.
Step 6 folds sentence browsing into the Study Practice card. The card directly
shows the curated order for all sentences as a compact, fast-scanning list
without a separate expansion button. A list toggle switches between Chinese
rows with pinyin and English rows; tapping a row opens the normal Study
information card for richer Phrase and Character inspection. The tapped sentence
stays visibly selected and remains clickable in the Practice list, so the main
list acts as the way back to the sentence card after sidebar phrase or character
exploration. Only Conversation Practice sentence cards repurpose the sidebar
`Phrase` button to show the verified phrases in that sentence; all other Phrase
and Character information-card contexts keep their normal broad phrase lookup
behavior.
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
toggles. Flashcards and Quick Quiz remain pinned below the list. Imported topic
deletion is an icon action beside the topic picker, not a full-width row.
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
adding a separate explanation row. Translate is a third lightweight Practice
drill with an in-sheet direction toggle for English-to-Chinese and
Chinese-to-English. It records correct/incorrect outcomes through the same
portable progress model and keeps sentence/character inspection inside the drill
sheet. The Translate drill is split by responsibility: the sheet owns lifecycle
and state, `ConversationPracticeTranslationQuizComponents.swift` owns view
sections, `ConversationPracticeTranslationQuizLogic.swift` owns session/progress
behavior, and `ConversationPracticeTranslationQuizSupport.swift` owns small
supporting types. Practice linked phrase/character hints are cached in
`RadixStoreConversationPractice` per practice item and invalidated when Practice
phrase libraries register or phrase-backed Study data refreshes, so drill sheets
do not repeatedly rediscover the same hints during SwiftUI redraws.
`CharacterDetailView` no longer embeds the old Breakdown/Derivatives lineage
grid; structure exploration remains available through the dedicated Character
Breakdown explorer instead of crowding the info card.
Added Phrases review is phrase-first: no search field, no persistent help text,
and no visible AI shortcut above the grid. The top row shows the status filter,
an `Actions` menu, and `Done`; `Actions` includes `Create AI Review Page` for
current unreviewed phrases, bulk status/deletion actions, and help. The AI
Review action creates a saved Browse page from all current unreviewed,
non-base added phrases, then opens that page in Browse with a `Back to Study`
return path. This action does not mark, accept, reject, or delete the source
phrases. Review phrases sort by pinyin, and pagination uses the visible pinyin
letter range such as `b-c` rather than page numbers. The sheet uses a paged
non-scrolling grid whose page size is calculated from the measured vertical
space above the footer; fixed platform counts are only first-render fallbacks.
On iPhone and iPad, the top controls sit below the drag indicator with extra
breathing room and use compact icon-and-word labels so `Actions` is less likely
to be confused with the dismiss handle. Status tools keep readable words and
icons rather than becoming icon-only.
The eligibility, ordering, page name, page-range label, and newline-delimited
source text are portable `AddedPhraseReviewRules` behavior with compatibility
tests so Android can share the same rule.
Content-driven cross-tab navigation uses the existing single-level return
context. Destinations show a named return button (`Back to Study`, `Back to My
Data`, and so on); manually choosing a primary tab clears that context.
Saved Browse pages use one labelled `Actions` menu for editing, OCR review,
phrase selection, translation, and AI workflows. The source chooser remains
separate navigation; only the script toggle and Read Aloud remain permanently
visible page controls.
Browse source actions use parallel source labels: text from the clipboard,
image from the clipboard, image from Album, image from Files, and saved-page
selection. Clipboard actions tell the user to copy the source content first;
Album and Files actions tell the user to choose the source image first.
Clipboard images use the same OCR page creation path as camera, album, and file
images. While the Browse source list is open, it is the active content; do not
show the dictionary or saved-page character grid behind or below it.
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
The global capture action is labelled `Camera` across iPhone, iPad, and Mac;
avoid reverting to `Take Photo` in visible navigation.
Local snapshots are presented as `Checkpoints` to avoid colliding with backup
language. On iPad and Mac, Checkpoints live in the sidebar when no
character/phrase information card is displayed; the section disappears while an
information card owns the sidebar focus. Top-level navigation and global
non-character/non-phrase actions clear the information card so Checkpoints
return to the sidebar once that contextual focus is no longer active. On iPhone,
where there is no persistent sidebar, Checkpoints remain at the bottom of Study
as a safety-net section after the main review content. The section has one
Create Checkpoint action and recent checkpoint rows; tapping a row is the return
action after confirmation, so there is no separate restore menu competing with
the learning content. Returning to a checkpoint always leaves the user in Study,
even if the checkpoint was created while another tab was active. iPhone Study
includes a compact `Backup files` bridge to My Data so users can still
distinguish local learning recovery from portable file protection.
My Data’s `Backup File` screen owns Backup File actions only. Backup
history stores lightweight file metadata and shows filenames; a selected backup
file restores immediately when the saved path is still readable, otherwise
Radix falls back to the file picker with the chosen Merge/Replace intent
preserved. My Data links back to Study for Checkpoints instead of duplicating
the checkpoint controls; this is a compact `Checkpoints` button, not explanatory
checkpoint copy.
Backup File actions keep the same three choices across iPhone, iPad, and Mac:
Create Backup, Merge Backup, and Replace from Backup. All platforms use a
readable two-row arrangement with Create Backup above Merge/Replace. My Data
content is width-capped inside its column so long explanations and action cards
do not visually spill to the screen edge.

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
