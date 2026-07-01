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
The first expansion topic is `Food / Eating Conversation`, covering restaurant
ordering, hawker centres or casual eateries, dinner-table conversation at home,
taste, price, portions, preferences, offering food, and polite responses.
The second expansion topic is `Trip to 4 Cities`, covering practical travel
Mandarin for Beijing, Shanghai, Guangzhou, and Taipei.
The third expansion topic is `Stay in Shanghai`, covering longer-stay Mandarin
for language study, housing, utilities, transport, local services, and
administrative tasks.

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

Radix also has an AI Link task for generating new Conversation Practice packs
from a selected topic. That task outputs the lightweight Practice JSON shape so
the result can be saved as a file, loaded through the Study dropdown, validated,
and imported without hand conversion.

Preferred AI/user import JSON shape:

```text
theme
entries[].id
entries[].zh
entries[].pinyin
entries[].en
```

Radix derives the stable pack ID, title, default category, character hints,
full-sentence phrase hint, metadata, and notes before validation.

Full incoming JSON format, used by `conversation100.json`, is also accepted:

```text
pack_id, version, title, description, language, source_type, created_for, entries
entries[].id
entries[].sequence
entries[].category
entries[].level
entries[].sentence.zh
entries[].sentence.pinyin
entries[].sentence.en
entries[].analysis.characters
entries[].analysis.phrases
entries[].metadata.difficulty
entries[].metadata.frequency
entries[].metadata.tags
entries[].notes
```

Fallback CSV shape for future conversion scripts:

```text
set_id,rank,simplified,pinyin,english,difficulty,tags,notes
general_greetings,1,...,...,...,easy,greeting;basic,...
```

Required fields:

- `pack_id`: stable pack identifier
- `entries[].id`: stable item identifier such as `conv-001`
- `entries[].sequence`: intended order inside the set
- `entries[].sentence.zh`: Simplified Chinese sentence with punctuation
- `entries[].sentence.pinyin`: pinyin with tone marks
- `entries[].sentence.en`: natural English translation
- `entries[].metadata.difficulty`: numeric source difficulty
- `entries[].metadata.tags`: scenario or function tags
- `notes`: optional usage notes or validation notes

Simplified uploaded packs may omit `source_type`, `created_for`, `sequence`,
`level`, `analysis`, `metadata`, and `notes`. The decoder supplies defaults
before validation so user- or AI-supplied content can still flow into the same
Practice model.

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
- provides a topic dropdown, with `General Greetings` as the first/default
  topic, `Food / Eating Conversation` as the second configured topic, `Trip to
  4 Cities` as the third, and `Stay in Shanghai` as the fourth
- shows difficulty, sentence count, progress, and last practiced state
- keeps upcoming sets visibly distinct from available sets
- lets a topic without bundled content open the AI generation task for that
  topic instead of pretending there are practice sentences ready
- lets the user import Practice JSON from the topic dropdown; valid imported
  packs are persisted, selected immediately, and shown as normal topics

Set detail:

- uses the sentence card as the central object
- offers `Flashcards` first
- offers `Quick Quiz` next
- lets the visible sentence preview expand in place to the full sentence list
- keeps every sentence tappable into its Phrase card or Browse inspection
- keeps the expanded Study list sparse, leaving detailed phrase and character
  exploration to the information card or drill feedback
- keeps the selected sentence highlighted and clickable in the main Practice
  list, so users can return to that sentence card without extra sidebar back or
  clear controls

Practice feedback:

- shows the sentence, pinyin, and English
- shows key Radix-backed words, sub-phrases, and characters where available
- offers simple results such as Again, Good, Easy, or correct/incorrect
- never dead-ends in a quiz-only screen where the dictionary/card system
  disappears
- opens Phrase and Character cards inside the current practice sheet, with the
  normal back button returning to Flashcards or Quick Quiz

## Initial Build Phases

1. Content schema and importer
   - Define the accepted CSV or JSON shape.
   - Build validation and duplicate reporting.
   - Import the first `General Greetings` draft as staged data.
   - Status: JSON schema and validation rules are implemented in
     `ConversationPracticeModels.swift`; `conversation100.json` decodes and
     validates through portable tests.

2. Phrase DB integration
   - Resolve or create Phrase DB-backed sentence records.
   - Add practice set membership and stable identifiers.
   - Add portable tests for ordering, validation, and membership behavior.
   - Status: validated packs now map into `ConversationPracticeLibrary`, with
     Phrase DB seed rows, stable membership IDs, punctuation-trimmed phrase
     keys, and a bundle-loading service for the starter pack.

3. Study entry point
   - Add `Conversation Practice` as a Study section.
   - Show set cards with count, difficulty, and progress.
   - Status: Study now loads the starter library and shows a first
     `Conversation Practice` section for `General Greetings`, including count
     and sample sentences that open through the normal Phrase card path.

4. Flashcards
   - Show Chinese first.
   - Reveal pinyin and English.
   - Add simple progress responses.
   - Link sentence and components back to Phrase and Character cards.
   - Status: `Flashcards` opens from the Study set card, reveals pinyin and
     English on demand, records Again/Good/Easy responses to portable Practice
     progress, and keeps Phrase/Character inspection inside the active sheet
     when users tap the sentence, phrase hints, or character hints.

5. Quick Quiz
   - Start with offline single-character recognition inside the source sentence.
   - Use script-aware component/confusability data for answer choices.
   - Show Radix-backed answer feedback after each question.
   - Status: `Quick Quiz` opens from the Study set card, samples up to 20
     practice items per run, blanks one character, builds script-aware choices
     from confusable/component peers with broader dictionary fallbacks, records
     correct/incorrect attempts to portable Practice progress, shows immediate
     feedback with pinyin/English and session score, and keeps Phrase/Character
     inspection inside the quiz sheet.

6. Embedded Sentence List
   - Let users expand the Study Practice card from a short sentence preview to
     every sentence in the selected set.
   - Preserve curated rank order.
   - Keep the expanded Study list sparse so users can scroll and scan quickly.
   - Link every full sentence back to existing Phrase and Character inspection
     through the normal Study information card.
   - Scope the sentence card's `Phrase` action to verified phrases in that
     sentence only; keep all non-Practice information-card phrase lookup
     behavior unchanged.
   - Status: The Study set card shows a compact preview and expands in place to
     all sentences in curated order. Expanded rows include Chinese, pinyin, and
     English only, without phrase or character chips. Flashcards and Quick Quiz
     keep detailed lesson-card inspection inside their active sheets.

7. Expansion
   - Add more situational sets.
   - Add more practice modes only after the core card links feel solid.
   - Status: Topic selection is in place as a reusable configuration layer.
     `Food / Eating Conversation` is the first expansion topic, backed by
     `Food Dining.json`; `Trip to 4 Cities` is the second expansion topic,
     backed by `Trip to 4 cities.json`; `Stay in Shanghai` is the third
     expansion topic, backed by `Stay in Shanghai.json`. AI Link provides a
     generator prompt that emits the lightweight importable JSON shape for
     future topics or draft replacement packs.

8. AI-generated practice packs
   - Add an AI Link task named `Generate Practice Pack`.
   - Render it from the selected Conversation Practice topic.
   - Require exact lightweight importable JSON with `theme` and flat
     `entries[].id`, `zh`, `pinyin`, and `en` fields.
   - Keep generated packs draft-only until validated by the existing
     `ConversationPracticeRules`.
   - Status: The generator task is built into AI Link. Study imports validated
     Practice JSON from the topic dropdown, persists imported packs in
     preferences, selects them immediately, registers their phrase cache, and
     lets users delete imported topics without affecting bundled topics.

9. Backup and transfer
   - Include imported Practice packs in portable backups and checkpoints.
   - Show Practice as its own backup-preview section rather than hiding imported
     packs inside generic app state.
   - Status: `UnifiedPackage` carries imported Conversation Practice packs and
     portable Practice progress. My Data's backup preview has a Practice section
     that summarizes selected topic, bundled topic count, imported pack count,
     and imported sentence counts.

## Next Build Candidates

These are the remaining useful Practice work items, in likely build order:

1. Persistent progress
   - Define a portable practice-progress model keyed by pack ID and item ID.
   - Store Flashcards responses, quiz attempts, last practiced date, and simple
     per-topic completion counts.
   - Include progress in backup/checkpoint flows after the storage contract is
     stable.
   - Status: A portable `ConversationPracticeProgressSnapshot` keyed by pack ID
     and item ID stores Flashcards responses, quiz attempts, completion state,
     and last-practiced dates; backup/checkpoint packages include it.

2. Progress-aware Study UI
   - Replace placeholder progress/last-practiced copy with real values from the
     progress model.
   - Keep the Practice card compact: topic, count, last practiced, and simple
     completion signal are enough.
   - Status: The focused Study Practice topic subtitle shows per-topic
     completion and last-practiced state without adding a separate explanation
     row.

3. Import review and replacement flow
   - Before replacing an imported pack with the same ID, show a compact summary
     of title, sentence count, and validation warnings.
   - Keep the current fast import path for valid first-time packs.

4. Practice audio/read-aloud
   - Reuse existing speech infrastructure for sentence read-aloud in Flashcards,
     Quick Quiz feedback, and the expanded sentence list.
   - Do not make audio required for offline practice.

5. Additional modes only after progress exists
   - Consider sentence-to-English or English-to-Chinese drills once the
     persistent progress model can track attempts consistently.
   - Keep every mode linked back to Phrase and Character cards.

## Non-Goals For First Version

- No AI requirement inside the user-facing lesson flow.
- No separate Chinese sentence database disconnected from Phrase DB.
- No gamified system before the basic Study and card integration works.
- No forced Added Phrases review workflow for curated lesson content.
- No complex spaced-repetition algorithm until the simple progress model has
  been tested.

## Open Decisions

- Whether practice progress belongs in preferences, SQLite, or a portable
  practice-progress store.
- Whether uploaded content should be reviewed in a staging screen before import
  when it replaces an existing imported pack.

## Resolved Decisions

- Practice stays inside the Study tab as a `Conversation Practices` summary
  tile that opens a focused Practice screen, not as a fifth main tab.
- Imported packs are user data in preferences and portable backups; bundled
  topics remain fixed app content.
- Phrase hint chips are database-verified exact matches only. Character chips
  omit characters already covered by displayed phrase chips, and shared script
  helpers keep Flashcards and Quick Quiz aligned.
