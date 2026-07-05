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
  Done.
- Convert imported/page-generated practice packs to store ordered sentence
  references. Done.

## Phase 3: Expansion

- Parse `[Radix Capture JSON]` blocks from AI outputs.
- Capture quiz and OCR-derived sentences where structure is reliable.
- Add a Sentence Examples browser with filters.
- Add edit, hide, delete, copy, and practice-again actions.

The rule is capture first, rank and curate later, but only from reliable
structured sources until the quality controls are in place.
