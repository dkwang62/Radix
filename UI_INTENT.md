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

## Main navigation intent

The four primary destinations use this plain-language division of responsibility
everywhere they are introduced or explained:

- `Browse` — inspect the dictionary or captured pages.
- `Study` — review what you decided to keep.
- `AI` — understand or transform material.
- `My Data` — protect, transfer, or export your work.

Search and Take Photo remain global actions outside this four-part vocabulary.

The compact-screen iPhone navigation should feel like:

```text
Top global action row:
[ Search anything... ] [ Take Photo ]

Bottom tabs:
Browse | Study | AI | My Data
```

Search and Take Photo are global actions, not ordinary tab destinations.

- Search is a core utility for characters, phrases, pinyin, meanings, saved
  pages, recent items, and added material. It should be reachable from almost
  anywhere and should not be buried inside Study.
- Take Photo is the fastest capture action. It should be globally visible on
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
- Take Photo can remain a visible toolbar/sidebar action rather than replacing
  the layout around a single compact action row.
- Save/Restore Snapshot can remain in the sidebar because there is enough space
  to keep learning-state controls visible without crowding the primary content.
- Do not remove or hide existing iPad/Mac affordances merely because the iPhone
  UI becomes more compact.

## Browse intent

Browse is for inspecting material.

Browse should be simple and not force unnecessary mode choices:

- Dictionary appears as the first browse item.
- Create from Paste appears as an action.
- Import from Album appears as an action.
- Import from Files appears as an action.
- Saved Pages appear as a list.

Entering Browse opens the most recently viewed saved page, using its scan date
when it has no separate viewing date. Dictionary remains available from the
source chooser but is not the default when saved pages exist.

Avoid a permanent Dictionary/Pages selector if a simple list can do the job.
Avoid repeating Take Photo inside Browse when the global Take Photo action is
already available.

When the user opens a saved page, returning to the page list should be obvious.
Dictionary should behave like another browse item and should not break the
navigation routine.

For an open saved page, keep navigation separate from page actions. The source
chooser remains a distinct back/photo control. Consolidate secondary commands
such as Edit Page, Check OCR, phrase selection, translation, and AI workflows
under one clearly labelled `Actions` menu. Keep only frequently adjusted
controls—Simplified/Traditional and Read Aloud—visible beside it.

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
- Study snapshots.

Items such as "Review Added Phrases" belong in Study, not My Data.

On iPhone, Study may need to contain explicit Snapshot sections because the
screen cannot permanently show a rich sidebar. On iPad and Mac, Save/Restore
Snapshot can remain a sidebar-level learning action instead of being buried
inside Study.

Study should not become a hodgepodge. Group it by intent:

- Today: what changed or was captured recently.
- Review: favorites, recent items, added items, notes, and saved pages.
- Snapshots: save and restore learning states.

The four Study summary buttons are the section selectors. Do not repeat
Recent/Favorites as a segmented picker above the review grid; the grid heading
should reflect the summary button most recently selected.
On iPad, arrange the four Study summary buttons as two equal-width buttons per
row so labels such as Added Phrases and Saved Pages remain fully readable.

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

## Protect and recover grammar

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
Study includes a compact `Backup files` link to My Data so users can learn the
difference without losing the quick Checkpoint workflow. Put Checkpoints at the
bottom of Study so the safety net is available without competing with the main
review choices. Show one Create Checkpoint action plus a scrollable list of
checkpoint rows; the rows themselves return to that checkpoint after
confirmation. Backup file rows in My Data offer Merge or Replace and use the
picker only when the exported file is no longer directly readable.

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
- Larger text in long-press help disclosures.
- Contextual help on icons when the tap action already does something else.

Keep roman text, pinyin, and helper labels legible. Avoid shrinking important
learning text below the app's current minimum readability floor.

The five primary navigation destinations use progressive guidance:

- `Icons & Labels` is the explicit startup default and keeps the short
  destination names visible after every launch.
- Experienced users may choose `Icons Only` in Settings for the current session.
- On iPhone, iPad, and Mac Catalyst, a normal navigation press must never open
  a guide; guides are available only by long-pressing a destination.
- Each explanation begins with why the destination matters, then describes what
  the user can do. Do not present a bare inventory of controls.
- Once dismissed, the explanation stays out of the way.
- Long-pressing a destination opens or reopens its explanation.
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
  saved-page tasks in AI Link. Their templates are editable in Customize, and
  Browse must render those same templates rather than maintaining separate
  hidden instructions.
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
  primary workflow uses Gemini to generate structured quiz questions, then Radix
  presents them inside the app. The sheet must be scrollable and must not allow
  the toolbar to obscure the page title, question, answers, or feedback. If
  Gemini is unavailable or no key is configured, explain that clearly and offer
  a local dictionary-backed fallback rather than showing a prompt editor.
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
