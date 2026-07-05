# Sentence Example Database Plan

Radix should converge on one canonical sentence store. Favorite sentences, page
sentences, Conversation Practice items, and future practice packs should be
views over sentence examples rather than separate sentence databases.

## Architecture

- `SentenceExampleRecord` is the canonical persisted sentence asset.
- Practice packs remain lightweight grouping/ordering metadata.
- Favorite sentences become a favorite flag on sentence examples, with existing
  records kept for compatibility during migration.
- Page-derived sentences link back to the saved page through source metadata.
- Practice progress should eventually key against sentence IDs or stable
  sentence keys.

## Phase 1: Foundation

- Add canonical sentence example model and exact normalized deduplication.
- Persist sentence examples in Radix preferences and portable backups.
- Capture sentences from Conversation Practice packs and favorite toggles.
- Show examples in character and phrase info cards.
- Preserve all existing practice UI and stored data.

## Phase 2: Unification

- Add lookup helpers for character, phrase, source page, source type, and hidden
  status. Done.
- Backfill legacy Favorite Sentences into sentence-example favorite flags and
  build the Favorite Sentences practice topic from canonical sentence examples.
  Done. Restore applies sentence examples before legacy favorite records so
  compatibility favorites overlay onto the canonical store. Favorite/unfavorite
  and delete actions keep the legacy compatibility list in sync with canonical
  sentence flags. Backup export prepares the canonical sentence store first so
  old compatibility records are not missed.
- Convert imported/page-generated practice packs to store ordered sentence
  references. Done.

## Phase 3: Expansion

- Parse `[Radix Capture JSON]` blocks from AI outputs. Done.
- Capture OCR-derived sentences where structure is reliable. Done.
- Capture quiz-derived sentences only after quiz workflows have an explicit
  structured return path that does not reveal answers early or scrape chat
  prose.
- Add a Sentence Examples browser with filters that reuses the Conversation
  Practice display toggle, row layout, and sentence info preview path. Done.
- Add practice-again action that reuses Conversation Practice flashcards. Done.
- Add edit action.
- Add favorite, hide, restore, delete, copy, and source-page actions. Done.

The rule is capture first, rank and curate later, but only from reliable
structured sources until the quality controls are in place.
