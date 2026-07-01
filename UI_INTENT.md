# Radix UI intent

This document records the product and UI intent for future refactors. Treat it
as the north star before changing tabs, primary actions, Browse, Study, AI, or
My Data.

## Product shape

Radix is a Chinese learning workspace built around this loop:

1. Capture Chinese from the world.
2. Find and inspect characters, phrases, and pages.
3. Understand the material with dictionary and AI support.
4. Remember what mattered.
5. Recover earlier learning states when the user changes their mind.

Avoid organizing the app around implementation names such as scan, file import,
backup internals, or data tables. The UI should be organized around what the
user is trying to do.

Inline alerts, notices, and status messages should sit on the next row below
the controls they respond to. Do not place feedback text in the same horizontal
row as action buttons; the message should never squeeze the buttons or compete
with the primary action.

## Main navigation intent

The four primary destinations use this plain-language division of responsibility
everywhere they are introduced or explained:

- `Browse` — inspect the dictionary or captured pages.
- `Study` — review what you decided to keep.
- `AI` — understand or transform material.
- `My Data` — protect, transfer, or export your work.

Search and Camera remain global actions outside this four-part vocabulary.

The compact-screen iPhone navigation should feel like:

```text
Top global action row:
[ Search anything... ] [ Camera ]

Bottom tabs:
Browse | Study | AI | My Data
```

Search and Camera are global actions, not ordinary tab destinations.

- Search is a core utility for characters, phrases, pinyin, meanings, saved
  pages, recent items, and added material. It should be reachable from almost
  anywhere and should not be buried inside Study.
- Camera is the fastest capture action. It should be globally visible on
  primary screens and route into the existing OCR/page creation flow.
- AI should remain first-class. It is a major product feature, not just a small
  Study subtool.
- My Data should not become a review drawer. It should focus on data ownership,
  backup, restore, export, import, and subscription-related data tools.

Do not move tabs one at a time without preserving this overall structure.

When an in-content action moves the user to another primary destination, show
one temporary, named return action such as `Back to Study` or `Back to My Data`.
It returns to the calling destination and its retained section state. Ordinary
tab-button navigation does not create a return path and clears any existing one.
Keep this single-level and contextual rather than building browser-style history.

This is an iPhone-first structure. Do not force the same simplification onto
iPad or Mac. Larger screens have enough room for a more generous workspace,
including sidebar actions and persistent panels, as long as the mental model
remains coherent.

On iPad and Mac:

- Preserve a more spacious sidebar/workspace layout.
- Search can be persistent or prominent in the sidebar/header.
- Camera can remain a visible toolbar/sidebar action rather than replacing
  the layout around a single compact action row.
- Save/Restore Snapshot can remain in the sidebar because there is enough space
  to keep learning-state controls visible without crowding the primary content.
- Do not remove or hide existing iPad/Mac affordances merely because the iPhone
  UI becomes more compact.

## Browse intent

Browse is for inspecting material.

Browse should be simple and not force unnecessary mode choices:

- Dictionary appears as the first browse item.
- Text from Clipboard appears as an action and tells the user to copy Chinese
  text first.
- Image from Clipboard appears as an action when an image is already on the
  clipboard and tells the user to copy an image first.
- Image from Album appears as an action and tells the user to choose a photo.
- Image from Files appears as an action and tells the user to choose an image
  file.
- Saved Pages appear as a list.

When the Browse source list is open, it is the active Browse content. Do not
show the dictionary or saved-page character grid behind or below it.

Entering Browse opens the most recently viewed saved page, using its scan date
when it has no separate viewing date. Dictionary remains available from the
source chooser but is not the default when saved pages exist.

Avoid a permanent Dictionary/Pages selector if a simple list can do the job.
Avoid repeating Camera inside Browse when the global Camera action is
already available.

When the user opens a saved page, returning to the page list should be obvious.
Dictionary should behave like another browse item and should not break the
navigation routine.

For an open saved page, keep navigation separate from page actions. The source
chooser remains a distinct back/photo control. Consolidate secondary commands
such as Edit Page, Check OCR, phrase selection, translation, and AI workflows
under one clearly labelled `Actions` menu. Keep only frequently adjusted
controls—Simplified/Traditional and Read Aloud—visible beside it.
Check OCR should use the saved page characters as the primary text to review.
The AI is asked to find likely capture/OCR anomalies in those page characters;
any source image or raw OCR provenance is supporting evidence only.

## Study intent

Study is the user's learning memory center.

Study should contain learning review material, not admin backup tools:

- Recent characters, phrases, and pages.
- Favorites.
- Added phrases.
- Added characters.
- Changed items.
- Notes.
- Saved pages to revisit.
- Conversation practice sets.
- Study snapshots.

Items such as "Review Added Phrases" belong in Study, not My Data.
From Added Phrases review, the user can create an `AI Review` saved page from
all currently unreviewed added phrases. That page opens in Browse so the normal
saved-page AI workflows can be used, while the original phrase statuses remain
unchanged. Keep the review surface phrase-first: no search field, no persistent
instruction blocks, and no separate AI shortcut above the grid. Put `Create AI
Review Page` under an obvious `Actions` menu with its unreviewed count, alongside
bulk actions and help. Sort phrases by pinyin and label pages by the visible
pinyin-letter range, such as `b-c`, rather than generic page numbers. Use a
paged grid, not an internal scroll view, and calculate the page size from the
visible grid height so the tiles fill down to just above the footer on each
platform. On iPhone and iPad, keep the top controls clearly below the sheet
drag indicator; prefer compact icon-and-word controls there, while status tools
should keep readable words and icons rather than becoming icon-only.

On iPhone, Study may need to contain explicit Snapshot sections because the
screen cannot permanently show a rich sidebar. On iPad and Mac, Checkpoints can
remain a sidebar-level learning action instead of being buried inside Study, but
they should disappear while a character or phrase information card is using the
sidebar.

Study should not become a hodgepodge. Group it by intent:

- Today: what changed or was captured recently.
- Review: favorites, recent items, added items, notes, and saved pages.
- Practice: guided lesson sets and drills such as Conversation Practice.
- Snapshots: save and restore learning states.

The Study tab splits internally into `Review` and `Practice`; do not create a
separate main app tab for Practice unless the whole navigation model is
reconsidered. Review holds the user's kept material; Practice holds guided
lesson content.

Inside Review, the four Study summary buttons are the section selectors. Do not
repeat Recent/Favorites as a segmented picker above the review grid; the grid
heading should reflect the summary button most recently selected.
On iPad and Mac Catalyst, arrange the four Study summary buttons as two
equal-width buttons per row so labels such as Added Phrases and Saved Pages
remain fully readable.

Conversation Practice should be a guided Study section built from Radix's
existing Character and Phrase dictionary infrastructure, not a separate
phrasebook app inside Radix. Present curated sets such as `General Greetings`,
`Restaurants`, `Airport`, and `Shopping Mall`; each set contains Phrase
DB-backed sentences with Simplified Chinese, pinyin, English, order, difficulty,
scenario grouping, and progress. The first starter set is `General Greetings`,
an easy-ranked collection of roughly 100 common conversational sentences.
Study should expose Conversation Practice topics through a compact dropdown so
the section can grow beyond the starter set. `General Greetings` stays first and
default. `Food / Eating Conversation` is the second bundled topic, using the
same practice controls as the starter set. `Trip to 4 Cities` is the third
bundled topic for travel situations across Beijing, Shanghai, Guangzhou, and
Taipei. `Stay in Shanghai` is the fourth bundled topic for longer-stay study,
housing, utilities, transport, local services, and administrative tasks. For
future generation-only topics, show the topic purpose and a clear action into
AI Link rather than empty practice controls.
The topic dropdown also owns importing user-supplied Practice JSON. Importing a
valid pack should add it as a normal selectable topic, select it immediately,
and show compact inline feedback below the dropdown rather than an alert.

Lesson screens should make the sentence card the main object. A user should be
able to review or quiz the sentence, then tap the full sentence into its normal
Phrase card or Browse inspection, tap detected words or sub-phrases into Phrase
cards, and tap individual characters into Character cards. Practice feedback
should reinforce those links by showing the sentence, pinyin, English, and key
Radix-backed parts after an answer. Avoid dead-end quiz screens where the
dictionary/card system disappears. When a lesson flow opens a Phrase or
Character card, keep that inspection inside the current lesson sheet with a
normal back path to the practice mode; do not eject the user from Flashcards or
Quick Quiz just because they inspected a Radix card. The Study Practice card
itself should make its visible sentence preview expandable to the full sentence
list, so users get sentence browsing without a separate primary section. In the
expanded card, sentence rows should stay sparse for scanning: Chinese, pinyin,
English, and a clear tap target into the normal Study information card. Do not
repeat phrase and character chips in that main list; the sidebar information
card is the richer inspection place. When that information card was opened from
a Conversation Practice sentence, its `Phrase` action should show only phrases
verified inside that sentence. This exception must not change normal Search,
Browse, Review, Favorites, or other information-card phrase lookup behavior.
The selected sentence should remain visibly highlighted and clickable in the
Practice list, making the main list the simple way back to the sentence card
after sidebar phrase or character exploration. The phone information preview
should not add extra `Study` or `Browse` shortcut buttons above this flow; when
a Practice sentence card is open on iPhone, provide a compact `Sentences`
return action to the expanded sentence list, and when a character preview can
return to its sentence card, label that action `Sentence`.
Character inspection in Practice should use the normal full character card, not
the compact preview.

Keep curated lessons visually and behaviorally separate from Added Phrases
cleanup. Added Phrases is for user/imported phrase classification; Conversation
Practice is guided learning content. It should support simple offline practice
first, such as Flashcards and Quick Quiz, with AI remaining optional future
enhancement rather than a requirement. Use `CONVERSATION_PRACTICE_PLAN.md` as
the project plan for content intake, validation, Phrase DB integration, and
build phases.

AI-generated Conversation Practice content should use the lightweight importable
Practice JSON shape with `theme` plus `entries[].id`, `zh`, `pinyin`, and `en`.
Do not ask AI for loose prose, markdown tables, or unvalidated phrase lists when
the app needs reusable lesson content.

## AI intent

AI remains a major app area.

AI should focus on understanding and transforming material:

- Translate.
- Explain.
- Extract phrases.
- Work with the current page, current selection, or current study snapshot.
- Manage AI Link actions and templates.

AI can be connected from Browse and Study, but it should not be hidden so deeply
that users miss it as a major Radix feature.
AI Link should start from the user's goal, not configuration. Show one compact
AI task menu with an obvious dropdown affordance and a `New AI Task...` option,
then the compact source confirmation row and open controls, then the editable
AI prompt template for that task only. Prompt editing should use an explicit
draft with `Save` and `Undo`, not invisible autosave. Built-in tasks should not
repeat the task title in a second title field; custom tasks may show a task-name
field. `Undo` restores the current task's default or starter prompt and shows a
compact next-row confirmation that editing can continue. Do not show a full
generated prompt preview on the AI Link screen; the AI chat will show the
prompt after copy/open. The source
selector should be obvious and come before action status; for saved-page tasks,
the page row itself is the dropdown and uses the same page icon grammar as
Browse. Do not repeat the selected page, subject, or task in a separate
ready-to-send label. Opening the current AI should copy the prompt first and
then open the provider, with the button naming the selected task, such as
`Open Gemini: Task 2`; alternate providers and copy-only are menu choices, not
competing primary buttons. Put launch/copy notices on the row below those
buttons so they never squeeze the open controls. Character and phrase tasks
default to the most recent subject in the memory strip. The subject row should
be the selector, with recent memory-strip items in its dropdown; do not add a
separate Search button there. Saved-page tasks default to the last viewed page.
Always show the chosen source before sending so the smart default remains
reversible and understandable.

## Backup and checkpoint grammar

Radix should use a consistent Save/Restore pattern, but the object must always
be explicit.

Keep recovery choices close to the job they serve:

- Study owns Create Checkpoint and checkpoint-row returns for local learning recovery.
- My Data owns Create Backup / Merge Backup / Replace from Backup for portable files.
- Save Export / Restore Export for Advanced Pro files.

Study should show Checkpoints directly because they are one-step undo points for
learning changes on the current device. My Data should not duplicate those
controls; it should show a small link back to Study when users look for
Checkpoints there.
On iPhone, Study includes a compact `Backup files` link to My Data so users can
learn the difference without losing the quick Checkpoint workflow. Put
Checkpoints at the bottom of iPhone Study so the safety net is available without
competing with the main review choices. On iPad and Mac, put Checkpoints in the
sidebar when no character/phrase information card is displayed; hide them while
that card is visible so the sidebar has one clear focus. Top-level navigation
and global actions that are not selecting a character or phrase should clear the
information card, making Checkpoints visible again. Show one Create Checkpoint
action plus recent checkpoint rows; the rows themselves return to that
checkpoint after confirmation. Backup file rows in My Data offer Merge or
Replace and use the picker only when the exported file is no longer directly
readable.

The shared meaning is:

- Save: preserve this state somewhere.
- Restore: bring a saved state back.

The noun tells the user what kind of saved state is involved.

## Study checkpoints

Study snapshots are not just disaster recovery. They support active learning and
mind-changing during a day.

Example use cases:

- The user walks through Beijing and scans many signs.
- Later the user reads a book and captures several sections.
- During study, the user deletes pages, changes favorites, edits phrases, and
  later wants some deleted material back.

Checkpoints should make this safe.

The preferred restore behavior for snapshots is:

- Add Back Missing Items: default, brings back missing pages/phrases/notes
  without erasing newer work.
- Replace Current State: advanced/destructive, returns fully to an earlier
  snapshot.

Manual Save Snapshot should exist, and automatic snapshots may be useful before
large deletes, after capture batches, or at natural session boundaries.

## My Data intent

My Data is for data ownership and operational safety:

- iCloud backup.
- Restore from backup.
- Export.
- Import.
- Advanced Pro files.
- Backup contents summary.
- Account/subscription/data ownership tools.

If My Data shows counts such as Saved Pages or Added Phrases, those rows should
link to Browse or Study rather than becoming separate review screens inside
My Data.

On iPhone, My Data should be action-first. Backup and restore choices should be
visible before inventory details. Backup contents should start collapsed behind
a clear "What is included?" disclosure so the screen does not repeat labels,
badges, and explanatory text before the user can act.

On iPad and Mac, My Data may keep the fuller backup contents panel visible
because there is enough space for review and action areas to coexist.

Advanced Exports are not ordinary backups. Their purpose is to provide a code
and structured-data foundation—project source, manifests, JSON, and SQLite
databases—that users can give to AI coding agents when authoring, adapting, or
building their own software. Explain this purpose directly wherever Advanced
Exports are introduced.

## Text and help intent

Small help text should not be relied on for understanding the app. On iPhone,
tiny explanatory text is often unreadable.

Prefer:

- Clear labels.
- Larger text in explicit help disclosures.
- Contextual help on icons when the tap action already does something else.

Keep roman text, pinyin, and helper labels legible. Avoid shrinking important
learning text below the app's current minimum readability floor.

The five primary navigation destinations use progressive guidance:

- `Icons & Labels` is the explicit startup default and keeps the short
  destination names visible after every launch.
- Experienced users may choose `Icons Only` in Settings for the current session.
- On iPhone, iPad, and Mac Catalyst, the first navigation press must only change
  destination. Selecting the same active destination twice in a row opens or
  reopens its guide.
- Each explanation begins with why the destination matters, then describes what
  the user can do. Do not present a bare inventory of controls.
- Once dismissed, the explanation stays out of the way.
- Settings includes `Show Navigation Tips Again` to reset first-visit guidance.

Do not replace this with permanent paragraphs on every destination screen.

AI Link should be explained as the way Radix goes beyond fixed traditional
dictionary coverage. Its purpose includes contextual translation, deeper
explanation, emerging phrases and concepts, current usage, and extracting useful
expressions from real material so they can return to Radix for study.
Use this same purpose-first explanation wherever AI Link, phrase extraction, or
translation is introduced: state the learner benefit before describing buttons,
API keys, copying, pasting, or other mechanics.

Search guidance must expose exact English matching with a visible example:
`=water` finds the meaning `water` without broadening it to terms such as
`waterproof`. Do not hide the equals sign behind an example button's action.
Do not advertise raw Apple stroke symbols as a Radix query type. Apple’s Stroke
keyboard may be explained only as a way to compose and select a completed Chinese
character before submitting that character to Search.

OCR review is an explicit, reversible workflow on saved OCR pages:

- Radix prepares original OCR plus recognized characters and nearby dictionary phrases.
- Without an API key, the user sends the instruction and available reference
  image to ChatGPT and pastes the structured answer back into Radix.
- When a Gemini API key is present, `Check OCR` also offers an automatic check
  using the same evidence and saved image.
- API-key setup belongs with all automatic AI actions, not under one task.
  Organize page AI actions by the user's task: `Check OCR`, `Extract Phrases`,
  `Translate Page`, and `Create Quiz`. Each task offers the same two methods:
  copy/paste with ChatGPT or automatic processing with Gemini. When no key is
  saved, the automatic choice becomes `Set Up Gemini API Key…`; it opens
  Settings with Private API Keys expanded and a contextual `Back to Browse`
  action.
- Check OCR, Extract Phrases, Translate Page, and Create Quiz also exist as
  saved-page tasks in AI Link. Their templates are editable as AI prompts in
  the selected task view, and Browse must render those same templates rather
  than maintaining separate hidden instructions.
- Their Browse submenus use the same two method labels: `Use Another AI App`
  copies a prepared instruction for ChatGPT, Gemini, or another service, while
  `Run Automatically in Radix` uses the saved Gemini API key. A one-time,
  dismissible explanation appears on the first method choice, continues that
  choice after dismissal, and remains available from `How Radix Uses AI`. It
  uses a full sheet rather than a menu-attached popover so iPad always shows the
  complete explanation and its action buttons.
- `Use Another AI App` is always shown, even when an API key is configured.
  API authorization does not guarantee service availability. If an automatic
  request fails, offer the matching copy-and-paste workflow immediately rather
  than leaving the user at an error message.
- Do not expose API-specific variants as additional AI Link tasks. `Extract
  Phrases` is one task; copy/paste and automatic Gemini execution are methods
  for running it, just as with Check OCR and Translate Page.
- Create Quiz starts page-only and should open a real in-app practice screen:
  one question at a time, answers hidden until the user chooses, immediate
  correct/wrong feedback, and English explanations after each answer. The
  automatic method uses Gemini to generate structured quiz questions, then Radix
  presents them inside the app. The no-key method uses the same `Use Another AI
  App` pattern as the other page AI tasks: copy/open the editable quiz template
  so ChatGPT, Gemini, or another service can quiz the user directly. The sheet
  must be scrollable and must not allow the toolbar to obscure the page title,
  question, answers, or feedback. If Gemini is unavailable or no key is
  configured on the automatic path, explain that clearly and offer a local
  dictionary-backed fallback rather than showing a prompt editor.
- The AI must mark proposed changes and uncertainty in a structured response.
- Corrected source text remains Chinese; every explanation, confidence reason,
  and uncertainty note is written in clear English.
- Radix assumes the user accepts the AI correction and immediately creates and
  opens a second corrected saved page. The original page remains unchanged and
  available in Browse as the reversible safety record.
- Corrected-page names preserve as much of the original 11-character name as
  possible and use a trailing numeric suffix (`1`, `2`, and so on) to distinguish
  the derived page.
- Phrase extraction and translation can then operate on the separately selected
  corrected page without obscuring the source record.

## Refactor guardrails

- Do not mix Apple Review fixes with large UI refactors unless explicitly asked.
- Do not change bundle IDs, signing, App Groups, or App Store/TestFlight settings
  as part of UI refactors.
- Do not hide Search unless it has already become a reliable global action.
- Do not hide AI while it is still one of Radix's main differentiators.
- Do not turn My Data into a study/review area.
- Keep Browse and Study navigation predictable on iPhone before expanding the
  same pattern to iPad and Mac.
