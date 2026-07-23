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

## Design decision rules

These rules should shape every new screen before implementation starts. They
capture the user's recurring preferences so new UI does not need to be corrected
after the fact.

### Put the user in control

Every exploratory, destructive, or cross-feature action needs a visible way back
to where the user came from. Prefer one contextual return action such as
`Back to Study` over hidden history. When a flow opens Phrase, Character, AI,
Browse, quiz, or review detail from another context, keep the return path inside
that flow instead of ejecting the user to a different destination.
Reference pages opened from primary tabs, such as Settings help or credits,
should be dismissible sheets or otherwise preserve tab access; they should not
push the user into a full-screen dead end with no visible route back.

Selection should stay visible when it matters. If a list opens detail, keep the
selected row highlighted or otherwise make the list itself the return path.
Checkpoint and backup restores must restore the data the user reasonably
believes was saved, and screens with local caches must refresh after restores so
the visible state matches the restored state.

### Fight for content space

Space belongs first to the learning object, second to controls that directly
manipulate it, and last to explanation, labels, and structure. Do not spend a
full row on a secondary action when an icon beside the related object will do.
Do not keep explanatory text on focused task screens once the user's context is
obvious.

Long lists should not make users scroll away from controls they need repeatedly.
Use paging, pinned actions, or compact local control rows when they preserve the
working surface. Floating controls are welcome only when they solve an actual
long-content problem; otherwise controls should live with the thing they affect.

### Remove duplicate meaning

Do not repeat the same noun, mode, count, or action in adjacent UI layers. One
concept gets one visible owner: a topic picker should not be followed by a card
header repeating the same topic; a focused Practice screen should not also show
a generic Study description; a normal tile should not be duplicated by a
separate mode switch.

Do not duplicate an existing interaction pattern in new code. Before creating a
new row, sheet, card, preview, or workflow for phrases, sentences, practice
items, page artifacts, or AI tasks, search for the current shared component and
reuse or extend it. A visually similar feature with different code is a product
bug because behavior, styling, accessibility, and future fixes will drift.

Labels should earn their space. Prefer concrete controls placed beside the
object they change over headers that merely restate the current screen. Combine
related controls into one local cluster when they operate on the same object,
such as page navigation, script choice, and display language for a sentence
list.
Sentence-list toolbars should use one shared, deterministic control row. Avoid
fixed-width segmented controls inside mixed rows; use compact one-button
toggles for binary modes such as Chinese/English so iPad split views do not
wrap labels into unusable vertical text. Do not wrap interactive toolbar
menus/buttons in a measurement-based multi-candidate layout that renders
several alternatives just to choose one.
For Study Sentences specifically, keep page navigation and display/script
choice on the top row. Put source filtering, compact sentence search, and one
tools dropdown on the lower source row on every device; the dropdown owns
selection, transfer, and bulk delete.
Language-learning controls should prefer meaningful text badges over generic
typography icons: use labels such as `中 Chinese`, `英 English`, and `拼 Pinyin`
instead of `Aa`/`textformat` symbols when the control changes language display
or pinyin visibility.

### Balance with best-practice guardrails

The design rules above should make Radix focused, but not cryptic. Add these
counterweights before declaring a UI done:

- Keep one small orientation cue on focused screens when users might return
  later and need to know where they are.
- Do not make every control local if that fragments scanning; a single clean
  toolbar can be better than several tiny clusters.
- Use progressive disclosure for secondary power features so first-time users
  can still discover import, generate, help, restore, or destructive actions.
- Preserve breathing room around the main learning object; compactness should
  feel calm and efficient, not crowded.
- Separate beginner clarity from expert efficiency with first-use, dismissible,
  or replayable help instead of permanent instruction blocks.
- Test compact layouts with small-phone width, larger text, and future
  localization before relying on tight one-row control designs.
- Prefer reversible hiding over permanent removal for guidance users may need
  later, such as an info button or replayable help card.
- Show small confirmations or visible state changes after import, delete,
  restore, page change, or other actions that alter the user's working context.

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
- In Search, the editable search field owns the current query. Results should
  show count and filtering controls without repeating the query as a second
  headline. Keep field actions such as clear and Recent Searches grouped at
  the trailing edge, while the leading magnifying glass remains decorative.
- Camera is the fastest capture action. It should be globally visible on
  primary screens and route into the existing OCR/page creation flow. The
  global Camera action should open the camera sheet immediately, with the full
  capture workbench and other source options visible underneath after the sheet
  is dismissed.
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

Browse should be simple and not force unnecessary mode choices. The title
dropdown selects Dictionary or a saved page. Camera/capture owns creating pages
from camera, clipboard, album, files, or pasted text.

Entering Browse opens the most recently viewed saved page, using its scan date
when it has no separate viewing date. Dictionary remains available from the
title dropdown but is not the default when saved pages exist.

Avoid a permanent Dictionary/Pages selector if the title dropdown can do the
job. Avoid repeating Camera, file, album, or clipboard source actions inside
Browse when the global Camera/capture flow already owns them.

When the user opens a saved page, returning to the page list should be obvious.
Dictionary should behave like another browse item and should not break the
navigation routine.

In Dictionary Browse, the `Dictionary` label should be a real disclosure button
with a visible chevron for help. Dictionary grid tools such as Components,
Simplified/Traditional, and Filters may use a second compact row when that keeps
labels readable and avoids misleading icon-only controls.

For an open saved page, keep navigation separate from page actions. The top
`Browse [page name]` title is the quick page selector for Dictionary and saved
pages, so the open-page card should not spend a separate header row repeating
the page name, icon, or character count. Do not add a separate in-content source
button; the title dropdown owns Dictionary/saved-page switching, while other
capture sources live under Camera/capture. Browse should own page-inspection
controls that only make sense while looking at the page, such as Edit Page and
Choose Page Phrases. Browse should not own saved-page artifact work such as
translation, AI OCR review, phrase extraction, quiz generation, sentence
extraction, page conversation generation, or deletion. Keep frequently adjusted
Browse controls—Simplified/Traditional and Read Aloud—visible beside the
character count.
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
pinyin-letter range, such as `b-c`, rather than generic page numbers; when
there are multiple pages, that label can open a direct page-jump menu. Use a
paged grid, not an internal scroll view, and calculate the page size from the
visible grid height so the tiles fill down to just above the footer on each
platform. Added Phrases review should be a focused Study workspace with a
visible `Back to Study` control rather than a temporary pop-out when launched
from Study. While a status tool is selected, preserve the active filter so
large queues shrink in place as the user paints classifications. Previewing a
phrase should use the same Phrase Info Card/sidebar path as Browse instead of a
separate large inline preview on sidebar layouts. Prefer compact icon-and-word
top controls there, while status tools should keep readable words and icons
rather than becoming icon-only.

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

The Study tab should not create a separate main app tab for Practice unless the
whole navigation model is reconsidered. The main Study screen holds the user's
kept material and local controls. The root title menu is the Study section
switcher on every platform; do not also show broad Study dashboard buttons for
Recent, Favorites, Saved Pages, Added Phrases, Conversation Practices,
Sentences, or Checkpoints inside the content area. Keep only compact controls
that affect the current section. Keep the History strip and title menu visible
across Study sections; embedded Study workspaces should not hide the shell. Do
not require a `Back to Study` return just to switch between these sections.
iPhone Checkpoints may remain a shortcut to a sheet because it is a snapshot
tool rather than a primary study list.
Favorite Sentences belongs inside Conversation Practices, so do not duplicate
it as a dashboard shortcut. Saved Pages should be the default Study scope
because page-linked work is the center of the page-first Study flow.
Conversation Practices should render as the focused Practice section under the
same Study controls, not as a separate screen with its own `Back to Study`
button. Do not show a persistent `Review | Practice` switch row on the Study
main screen.
Conversation Practice should look and behave like Study Sentences on every
platform: the list owns the screen, page/navigation and Chinese/English
controls stay in the compact local control row, default page sizes match across
sentence-based Study surfaces, and secondary drills live in a small tools menu.
Sentence source filtering should be one compact menu/toggle, not a row of
separate source buttons. Do not add a bottom Translate/Quiz bar or a separate
framed practice card shell. Local Translate Quiz has been removed; translation
practice should be AI-backed if it returns.

Inside Review, the root title menu is the section selector. Do not repeat
Recent/Favorites as another segmented picker above the review grid; the grid
context belongs in the root title as `Study - [section]`, so do not repeat the
same section name again in the content area. Keep local review-control rows
pinned above the scrolling review content so long lists do not hide the main
navigation and controls.
Empty states in Study should be short and action-oriented: no saved pages should
point toward Camera, paste, or image import; no favorites should point toward
starring items; no recent items should point toward searching, browsing, or
inspecting Chinese. Avoid generic empty text that leaves the user with no next
step.
Saved Pages in Study owns page learning artifacts and deletion. Each saved-page
row should be collapsed by default when browsing the list, with only the page
number, title, thumbnail, small artifact indicators, and expand affordance
visible. Keep collapsed rows flush with zero vertical gap so large page
libraries scan like a compact table. Highlight the row for Browse's currently
selected saved page so returning from Browse preserves orientation. Tapping the
row expands that page in place; the expanded state offers the `Actions` menu for
viewing or saving translation, AI OCR review, phrase extraction, quiz generation,
sentence extraction, page conversation generation, and deleting the page with
its impact summary. Show a compact `Phrases` artifact chip when Radix finds any
base or added phrases on the page.
On iPhone, expanded saved-page controls should be thumb-sized even though
collapsed rows stay compact; prefer wider `Actions` and `Browse` controls once
the user has opened a row.
Resume signals in the collapsed list should stay selective: show last-viewed
context for the active Browse page or the top recently viewed page, but do not
add date/status text to every saved-page row.
The saved-page list must stay lazy and responsive: row drawing should not run
full page-phrase scans for every saved page. Use recorded phrase-extraction
links or already-warmed caches for row indicators, and do the full phrase lookup
only when the user opens the page phrase sheet.
It should use the same Phrase Library sheet and Phrase Info Card path as the
information-card Phrase button, scoped to the saved page and sorted by pinyin.
On sidebar layouts, selecting a page phrase should dismiss the phrase table so
the Phrase Info Card is unobstructed. Show
sentence-extraction results as `Sentences` and generated
page conversation results as `Conversation`, while both can still open into the
Practice flow. Opening the page in Browse should be an explicit inspection action
with a clear return to Study; editing the page text and choosing visible page
phrases belong in Browse.
When an OCR correction creates a corrected page, Study should let the user
promote that correction to become the main saved page. Promotion must keep
page-linked learning artifacts attached to the main page and let the user choose
whether the original OCR remains as a separate archived page or is discarded.

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
and show compact inline feedback below the dropdown rather than an alert. If an
imported topic can be deleted, keep deletion as a compact icon action beside
the topic picker rather than a full-width destructive row.
The focused Practice screen should not repeat the generic Study description or
add a separate `Conversation Practice` section header; the topic picker and
sentence controls are enough context.

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
itself should show sentence browsing directly, without a separate primary
section or a teaser/expansion step. Use compact page controls rather than a
long internal sentence scroll when a set contains many rows. Rows should stay
sparse for scanning, with a toggle between Chinese plus pinyin and English-only
display, and a clear tap target into the normal Study information card. Do not
repeat phrase and character chips in that main list; the sidebar information
card is the richer inspection place. When that information card was opened from
a Conversation Practice sentence, its `Phrase` action should show only phrases
verified inside that sentence. This exception must not change normal Search,
Browse, Review, Favorites, or other information-card phrase lookup behavior.
The selected sentence should remain visibly highlighted and clickable when its
page is visible, making the Practice list the simple way back to the sentence
card after sidebar phrase or character exploration. The phone information preview
should not add extra `Study` or `Browse` shortcut buttons above this flow; when
a Practice sentence card is open on iPhone, provide a compact `Sentences`
return action to the expanded sentence list, and when a character preview can
return to its sentence card, label that action `Sentence`.
Sentence source filters must also provide source navigation: a selected sentence
should name its origin, `From Pages` sentences should expose a direct way to
open the saved page, and `From Practice` sentences should expose a direct way to
open the originating practice set, with the sentence selected when possible.
Character inspection in Practice should use the normal full character card, not
the compact preview.

Keep curated lessons visually and behaviorally separate from Added Phrases
cleanup. Added Phrases is for user/imported phrase classification; Conversation
Practice is guided learning content. It should support simple offline practice
first, such as Flashcards and Quick Quiz, with AI remaining optional future
enhancement rather than a requirement. Content intake, validation, Phrase DB
integration, and practice progress rules live in `PROJECT_CONTEXT.md` as current
architecture rather than in separate completed plan files.

AI-generated Conversation Practice content should use the lightweight importable
Practice JSON shape with `theme` plus `entries[].id`, `zh`, `pinyin`, and `en`.
Do not ask AI for loose prose, markdown tables, or unvalidated phrase lists when
the app needs reusable lesson content.
After AI Link imports one of these Practice JSON packs, keep the workflow
complete by showing a direct action into Study for that imported practice. The
focused Study Practice screen should preserve a contextual `Back to AI Link`
return path. Keep AI Result controls above the pasted answer, bound the result
text height, and auto-collapse long pasted text after a successful import so
follow-up actions stay visible without scrolling through generated JSON.
Keep Conversation Practice sentences short enough for study and sidebar
inspection, but do not enforce a hard total-character limit. Longer source
meaning may stay in one complete, speakable practice line when that is the best
study material. The sidebar should adapt by focusing on navigable
four-character animation groups and should not duplicate the full sentence or
pinyin already visible in the main Practice list.

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
ready-to-send label. The task selector and source selector should read as the
same family of compact menu-card controls. Opening the current AI should copy
the prompt first and then open the provider, with the button naming the selected
task, such as
`Open Gemini: Task 2`; alternate providers and copy-only are menu choices, not
competing primary buttons. Put launch/copy notices on the row below those
buttons so they never squeeze the open controls. Character and phrase tasks
default to the most recent subject in the memory strip. The subject row should
be the selector, with recent memory-strip items in its dropdown; do not add a
separate Search button there. Saved-page tasks default to the last viewed page.
Always show the chosen source before sending so the smart default remains
reversible and understandable.
Settings should not make AI configuration feel like one large key vault. Keep
`AI Link` settings about where manual prompts open, keep `Automatic AI` for
Gemini key/model setup used by direct Radix actions, and keep `Manual AI Keys`
for non-Gemini provider keys used by copy-and-paste workflows.

## Backup and checkpoint grammar

Radix should use a consistent Save/Restore pattern, but the object must always
be explicit.

Keep recovery choices close to the job they serve:

- Study owns Create Checkpoint and checkpoint-row returns for local learning recovery.
- My Data owns Create Backup / Merge Backup / Restore Backup for portable files.
- Save Export / Restore Export for Advanced Pro files.

Study should show Checkpoints directly because they are one-step undo points for
learning changes on the current device. My Data should not duplicate those
controls; it should show a small link back to Study when users look for
Checkpoints there.
On iPhone, Study includes a compact `Backup files` link to My Data so users can
learn the difference without losing the quick Checkpoint workflow. Put
Checkpoints at the bottom of iPhone Study so the safety net is available without
competing with the main review choices, and show the full retained checkpoint
list rather than trapping most rows behind a tiny inner scroll. On iPad and Mac,
put Checkpoints in the sidebar when no character/phrase information card is
displayed; hide them while that card is visible so the sidebar has one clear
focus. Top-level navigation and global actions that are not selecting a
character or phrase should clear the information card, making Checkpoints
visible again. The sidebar may show only recent checkpoint rows, but it should
label the subset when more exist. The rows themselves return to that checkpoint
after confirmation. In My Data, Create Backup means create a new file from
memory. Merge Backup means combine the file and memory so both contain the
merged contents. Restore Backup means replace memory with the file and must
stay explicitly destructive. Checkpoint means save the current state as a
memory checkpoint. Backup file rows use the picker only when the exported file
is no longer directly readable.

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

History is the user-facing name for the working-memory strip used during
exploration, not a global app breadcrumb. Show it on Search, Browse, Character
Breakdown, and Study, where it helps users confirm that inspected sentence
characters and phrases were remembered. Keep it off My Data, AI Link, Settings,
and Camera unless a future workflow has a specific exploration need. Study
still uses Recent for deliberate review; History is only the lightweight
working-memory strip. The History clock icon must expose the word `History` on
hover and tap.
Sentence-based practice screens should not record a sentence in History merely
because the sentence row was opened. Record only the character or phrase the
user deliberately previews from that sentence. Keep the visible strip off
focused sentence cards so sentence details remain centered on the sentence.

Glossary rows should include a relevant icon beside the term so users can connect
the written label to the symbols they see elsewhere in the app.

The five primary navigation destinations use progressive guidance:

- `Icons & Labels` is the explicit startup default and keeps the short
  destination names visible after every launch.
- Experienced users may choose `Icons Only` in Settings for the current session.
- On iPhone, iPad, and Mac Catalyst, the first navigation press must only change
  destination, and reselecting the active destination must not open help. Put
  contextual help in the screen title menu instead; guided destinations show
  `Help` as the first dropdown option, and Browse places it above `Dictionary`.
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
  `Translate Page`, `Create Quiz`, `Extract Sentences`, `Sentence Practice`,
  and `Create Conversation`. Each task offers the same two methods: copy/paste with ChatGPT or
  automatic processing with Gemini. When no key is saved, the automatic choice
  becomes `Set Up Gemini API Key…`; it opens Settings where `Automatic AI`
  exposes Gemini setup, with a contextual `Back to Browse` action.
- Check OCR, Extract Phrases, Translate Page, Create Quiz, Extract Sentences,
  Sentence Practice, and Create Conversation also exist as saved-page tasks in AI Link. Their
  templates are editable as AI prompts in the selected task view, and Browse
  must render those same templates rather than maintaining separate hidden
  instructions. Manual `Use Another AI App` actions from Browse should route
  into that same AI Link task/result workflow with the saved page selected and
  a contextual `Back to Browse` return path.
- Conversation-generating AI tasks show one compact quantity selector beside
  the selected topic/page, defaulting to 25 entries with 50 and 100 as larger
  choices. Keep this as a shared control for future similar tasks rather than
  adding per-template count fields or hardcoded prompt sizes.
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
- Create Quiz is page-only and belongs to AI Link, not a local Radix quiz
  screen. Pressing a page `Quiz` chip opens the saved-page `Create Quiz`
  template in AI Link so ChatGPT, Gemini, or another AI chat can quiz the user
  directly. The prompt asks for Simplified Chinese by default and tells the AI
  to reframe the quiz in Traditional Chinese when the learner asks. Radix does
  not import a quiz result for this task, and it must not offer a local
  dictionary-backed quiz fallback.
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
