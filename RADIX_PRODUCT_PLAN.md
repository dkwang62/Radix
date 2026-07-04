# Radix Product Plan

This plan captures the accepted direction for making Radix more appealing and
more intuitive. The guiding product story is:

```text
Scan -> Review -> Practise -> Keep
```

## Core Promise

Radix turns the Chinese learners encounter in daily life into personal study
material.

By real Chinese, Radix means the Chinese a learner actually meets: a restaurant
menu, magazine page, book page, sign, subtitle, article, screenshot, message, or
other source from the world around them.

## The Learning Loop

### Scan

Capture Chinese from the world through camera, photos, files, clipboard, or
saved text. The result should feel like creating a learning page, not merely
running OCR.

### Review

Help the learner understand what is inside the page:

- characters
- phrases
- meanings
- pronunciation
- stroke order
- components and structure
- translation
- notes
- original page context

Review should feel like a page-level stage, not scattered inspection tools.

### Practise

Turn the reviewed material into active learning:

- extracted phrases
- extracted sentences
- conversation practice
- quizzes
- favorite sentences
- page-inspired practice packs

Practice created from a page should always keep its source visible and provide a
return path back to that page.

### Keep

Make the accumulated learning feel visible and valuable:

- saved pages
- notes
- favorites
- recent discoveries
- added phrases
- conversation practice
- checkpoints
- backups and exports

Keep is Radix's memory advantage. It should make the learner feel that every
useful encounter with Chinese can become part of a durable personal library.

## Product Priorities

1. Make saved pages feel like the heart of Radix, closer to a learning library
   than a storage list.
2. Make the page workflow obvious: scan a page, review it, create practice, and
   keep everything connected.
3. Prefer outcome language over implementation language. For example, use
   `Create Practice` or `Practice From This Page` where that is clearer than a
   raw AI task name.
4. Add page-aware progress cues where useful: phrases found, notes added,
   practice created, favorites saved, last reviewed.
5. Keep visible return paths between pages, practice, AI workflows, and Study.
6. Preserve the user's data ownership story through backups, exports, and
   durable saved pages.

## Page Artifacts and Lineage

If the page is the center of the Radix experience, generated learning material
must stay tied to its source page.

The mental model is:

```text
Original Page
  -> corrected OCR page
  -> translation
  -> extracted phrases
  -> extracted sentences
  -> quiz
  -> conversation practice
  -> notes
  -> favorites and review progress
```

The learner should be able to open a saved page and see what was created from
it. Months later, the page should still explain its own learning history.

### Owned by the Page

These artifacts should be deleted with the page after clear confirmation:

- corrected OCR page and OCR review results
- page translation
- page quiz
- extracted sentence practice
- page-created conversation practice
- page-local notes
- page-local AI result imports

### Linked to the Page

These artifacts can outgrow the source page and may need to survive as general
learning material:

- added phrases
- favorite characters
- favorite phrases
- favorite sentences
- notes attached to global character or phrase cards
- practice progress that belongs to a reusable practice set

Deleting a page should not silently erase globally useful learning material.
Instead, Radix should distinguish between page-owned artifacts and globally
linked material.

### Deletion Experience

Deleting a saved page should show a summary such as:

```text
Delete this page and its learning material?

This will delete:
- corrected OCR page
- saved translation
- page quiz
- extracted sentence practice
- page-created conversation practice
- page-local notes

Linked phrases and favorites can be kept unless they are only used by this page.
```

The safer default is to remove page-owned artifacts and page links while keeping
global study items. A future advanced option can offer to also delete items that
exist only because of that page.

### Implementation Direction

Introduce a page artifact model before making page-centered deletion automatic.
Each generated artifact should record:

- source page ID
- artifact type
- display title
- created date
- ownership mode: page-owned or globally linked
- deletion behavior

This makes the `Keep` stage concrete: Radix preserves not only a page, but the
learning material and decisions created from that page.

## Copy Direction

Use this plain-language frame in App Store copy, screenshots, welcome guidance,
and help:

> Scan a page from the world around you.
> Review the characters, phrases, meanings, pronunciation, notes, and original
> context.
> Practise with vocabulary, sentences, and conversation exercises created from
> that material.
> Keep everything connected, so months later you can return to the same page and
> continue learning from it.

## Reversal Point

Before this plan was documented and the current working tree was committed, a
safety tag was created:

```text
safety/pre-scan-review-practise-keep-plan
```

If this direction turns out to be wrong, return the repository to that point
with:

```bash
git reset --hard safety/pre-scan-review-practise-keep-plan
```

Use that only when intentionally discarding the plan commit and any commits made
after it.
