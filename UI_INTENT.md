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

Avoid a permanent Dictionary/Pages selector if a simple list can do the job.
Avoid repeating Take Photo inside Browse when the global Take Photo action is
already available.

When the user opens a saved page, returning to the page list should be obvious.
Dictionary should behave like another browse item and should not break the
navigation routine.

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

## Save and restore grammar

Radix should use a consistent Save/Restore pattern, but the object must always
be explicit.

Use the same visual grammar for:

- Save Snapshot / Restore Snapshot in Study.
- Save Backup / Restore Backup in My Data.
- Save Export / Restore Export for Advanced Pro files.

Avoid generic buttons that only say Save or Restore without saying what is being
saved or restored.

The shared meaning is:

- Save: preserve this state somewhere.
- Restore: bring a saved state back.

The noun tells the user what kind of saved state is involved.

## Study snapshots

Study snapshots are not just disaster recovery. They support active learning and
mind-changing during a day.

Example use cases:

- The user walks through Beijing and scans many signs.
- Later the user reads a book and captures several sections.
- During study, the user deletes pages, changes favorites, edits phrases, and
  later wants some deleted material back.

Snapshots should make this safe.

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

- `Icons & Labels` is the explicit product default and keeps the short
  destination names visible.
- Experienced users may choose `Icons Only` in Settings.
- The first visit to Browse, Study, AI Link, My Data, or Settings shows one
  dismissible explanation with concrete actions available in that destination.
- Once dismissed, the explanation stays out of the way.
- Long-press/right-click on a destination can reopen its explanation.
- Settings includes `Show Navigation Tips Again` to reset first-visit guidance.

Do not replace this with permanent paragraphs on every destination screen.

## Refactor guardrails

- Do not mix Apple Review fixes with large UI refactors unless explicitly asked.
- Do not change bundle IDs, signing, App Groups, or App Store/TestFlight settings
  as part of UI refactors.
- Do not hide Search unless it has already become a reliable global action.
- Do not hide AI while it is still one of Radix's main differentiators.
- Do not turn My Data into a study/review area.
- Keep Browse and Study navigation predictable on iPhone before expanding the
  same pattern to iPad and Mac.
