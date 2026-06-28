# Conversation Practice Plan

This plan defines how Radix will add curated conversational lesson sets without
becoming a separate phrasebook app. The feature must build on Radix's existing
Character and Phrase dictionary infrastructure.

## Goal

Add a new Study section named `Conversation Practice` for guided practice of
common conversational sentences. The first starter set is `General Greetings`:
about 100 easy, common beginner sentences in Simplified Chinese with pinyin and
natural English.

Later sets may include restaurants, airports, shopping, hotels, transport,
small talk, work, appointments, and increasingly complex sentence patterns.

## Core Principle

Every lesson sentence is a Radix Phrase-backed learning object.

Practice sets add curation, order, scenario, difficulty, and progress. They do
not replace or bypass:

- Phrase DB records
- Phrase cards
- Character cards
- Browse inspection
- favorites and notes where available
- Study memory and review state

If a lesson screen cannot lead the user back into Radix Phrase and Character
cards, it is not integrated enough.

## Content Sources

Content may come from Codex, the user, or other AI tools. Treat all submitted
content as draft material until normalized and reviewed.

Preferred incoming format:

```text
set_id,rank,simplified,pinyin,english,difficulty,tags,notes
general_greetings,1,...,...,...,easy,greeting;basic,...
```

Required fields:

- `set_id`: stable set identifier such as `general_greetings`
- `rank`: intended order inside the set
- `simplified`: Simplified Chinese sentence with punctuation
- `pinyin`: pinyin with tone marks
- `english`: natural English translation
- `difficulty`: starter values such as `easy`, `medium`, `hard`
- `tags`: semicolon-separated scenario or function tags
- `notes`: optional usage notes or validation notes

Optional future fields:

- key phrase hints
- grammar pattern
- formality
- region/style note
- audio/read-aloud preference
- distractor difficulty for quizzes

## Content Validation

Before importing content into app data, validate:

- Simplified Chinese only for starter sets
- pinyin includes tone marks and matches the Chinese
- English is natural, not overly literal
- sentence is common, modern Mainland Mandarin unless tagged otherwise
- no duplicates or near-duplicates within a set
- no rare, literary, overly formal, or textbook-only phrasing in beginner sets
- punctuation is consistent
- rank order moves from simpler to slightly richer usage

Anything uncertain should be flagged for human review rather than silently
imported.

## Data Model Direction

Use a two-layer model:

1. Phrase source layer
   - The Chinese sentence is stored as, or resolves to, a Phrase DB record.
   - Existing phrase lookup, cards, favorites, notes, and Browse inspection
     remain available.

2. Practice set layer
   - References Phrase DB records by stable identifier.
   - Stores set membership, rank, difficulty, scenario tags, and progress.
   - Does not duplicate language data except for import staging or validation.

Practice progress should be separate from Added Phrases classification. Users
should not accept, reject, or hide curated shipped lesson sentences as if they
were imported phrase candidates.

## UI Direction

Add `Conversation Practice` under Study as guided learning content.

Set list:

- shows curated sets such as `General Greetings`, `Restaurants`, `Airport`,
  and `Shopping Mall`
- shows difficulty, sentence count, progress, and last practiced state
- keeps upcoming sets visibly distinct from available sets

Set detail:

- uses the sentence card as the central object
- offers `Review Cards` first
- offers `Quick Quiz` next
- lets the user browse the full sentence list
- keeps every sentence tappable into its Phrase card or Browse inspection
- exposes detected characters and sub-phrases as links into existing cards

Practice feedback:

- shows the sentence, pinyin, and English
- shows key Radix-backed words, sub-phrases, and characters where available
- offers simple results such as Again, Good, Easy, or correct/incorrect
- never dead-ends in a quiz-only screen where the dictionary/card system
  disappears

## Initial Build Phases

1. Content schema and importer
   - Define the accepted CSV or JSON shape.
   - Build validation and duplicate reporting.
   - Import the first `General Greetings` draft as staged data.

2. Phrase DB integration
   - Resolve or create Phrase DB-backed sentence records.
   - Add practice set membership and stable identifiers.
   - Add portable tests for ordering, validation, and membership behavior.

3. Study entry point
   - Add `Conversation Practice` as a Study section.
   - Show set cards with count, difficulty, and progress.

4. Review Cards
   - Show Chinese first.
   - Reveal pinyin and English.
   - Add simple progress responses.
   - Link sentence and components back to Phrase and Character cards.

5. Quick Quiz
   - Start with Chinese-to-English multiple choice.
   - Use lesson-set items as answer pools.
   - Show Radix-backed answer feedback after each question.

6. Expansion
   - Add more situational sets.
   - Add more practice modes only after the core card links feel solid.

## Non-Goals For First Version

- No AI requirement inside the user-facing lesson flow.
- No separate Chinese sentence database disconnected from Phrase DB.
- No gamified system before the basic Study and card integration works.
- No forced Added Phrases review workflow for curated lesson content.
- No complex spaced-repetition algorithm until the simple progress model has
  been tested.

## Open Decisions

- Whether imported lesson phrases should be bundled standard data, user data, or
  a new curated-data category.
- Whether practice progress belongs in preferences, SQLite, or a portable
  practice-progress store.
- Whether practice sets should appear as a fifth Study summary tile or as a row
  inside the existing Review area.
- How much automatic character/sub-phrase detection is needed for the first
  version.
- Whether uploaded content should be reviewed in a staging screen before import
  or validated through a developer script first.
