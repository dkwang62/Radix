# Radix Version 1.1 Plan

Version 1.1 turns Radix from adjacent character, phrase, sentence, and page
tools into a linked learning graph. The page becomes the source workspace, the
sentence becomes the main meaning unit, phrases become reusable memory units,
and characters remain the atomic detail layer.

## Recovery Point

The current pre-1.1 application is preserved at:

```text
radix-v1.0-before-v1.1
```

Loose pre-existing worktree baggage was stashed as:

```text
pre-v1.1-baggage-2026-07-12
```

Use the tag as the app recovery point if Version 1.1 proves wrong. Use the stash
only if one of the loose files is later found to contain intentionally saved
work.

## Product Model

Radix 1.1 uses four linked learning objects:

- Page: the source workspace. It owns the original capture and page-level
  learning artifacts.
- Sentence: the meaning unit. It belongs to a page, contains phrases, and links
  down to characters.
- Phrase: the reusable memory unit. It can appear in many sentences and pages.
- Character: the atomic inspection unit for components, stroke animation,
  etymology, and recognition.

The intended movement is:

```text
Page -> Sentence -> Phrase -> Character
Character -> Phrase examples -> Sentence -> Page
```

Users should feel they are zooming in and out of the same material, not jumping
between unrelated tools.

## Page Layers

Saved pages gain two explicit page-text layers:

- Original OCR: the captured page as Radix received it. Browse shows this layer
  because Browse is for inspecting source material.
- AI-cleaned page: AI-treated prose created from the Original OCR. It should
  correct OCR mistakes where possible, restore complete sentence flow, and
  expand telegraphic media shorthand into fuller learning sentences. Study shows
  this layer because Study is for learning from material the user decided to
  keep.

The AI-cleaned page is page-owned. Deleting the page should delete the cleaned
page artifact, while durable learning memory such as favorites and progress
should follow existing retention rules.

## AI Task

Add a saved-page AI task:

```text
Create AI-Cleaned Page
```

The task should reuse the existing AI Link/manual/API flow. It should ask the AI
to return structured JSON containing:

- cleaned page title
- cleaned Chinese text
- sentence list
- optional English summary or sentence translations if useful
- notes about major OCR repairs or inferred expansions

The prompt must distinguish faithful OCR correction from interpretation:
expanded media shorthand is allowed, but the AI should not invent unrelated
facts. This is learning material, not a news rewrite.

## Browse Behavior

Browse remains source inspection:

- Saved-page Browse shows the Original OCR/source characters.
- Browse keeps page-specific inspection tools such as Edit Page and Choose Page
  Phrases.
- Browse may expose a route to Study for the page, but it should not replace the
  source view with AI-cleaned prose.

## Study Behavior

Study becomes the page-centered learning workspace:

- Saved-page rows open a page workspace.
- The page workspace shows AI-cleaned page content when available.
- If no AI-cleaned page exists, Study clearly offers the AI task to create it.
- Page artifacts remain grouped under the page: cleaned page, sentences,
  phrases, translation, quiz, conversation practice, and notes.

## Sentence Study Card

Replace the current sentence information card with a sentence-first learning
surface:

- Whole Chinese sentence first, with read-aloud and script controls nearby.
- English meaning below the sentence.
- Pinyin hidden behind a control rather than shown by default.
- Phrase map chips showing the phrases inside the sentence.
- Tapping a phrase chip opens the shared Phrase Info Card/sidebar path.
- Unknown phrase chunks can become candidate add-phrase chips.
- Sentence structure/grammar view replaces the current character-animation
  emphasis.
- Character animation moves behind a secondary Characters/Animation action.

This surface should reuse the existing Conversation Practice sentence rendering
where possible instead of creating a parallel sentence renderer.

## Navigation Contract

Every linked object needs an obvious return path:

- From Study page workspace to Study list.
- From sentence to page.
- From phrase to sentence or page when launched from a sentence.
- From character to phrase/sentence/page context when launched from linked
  study material.

Selection should remain visible where practical, especially in page and sentence
lists.

## Implementation Slices

1. Establish page artifact/data contracts for AI-cleaned pages without changing
   visible workflows.
2. Add the Create AI-Cleaned Page AI task using the existing AI Link flow.
3. Add import/storage for AI-cleaned page JSON and link it to the source page.
4. Show Original OCR in Browse and AI-cleaned page in Study page workspace.
5. Build the shared Sentence Study Card from existing sentence/practice
   components.
6. Add phrase map extraction/display inside the sentence surface.
7. Wire object-to-object return paths and active selection highlighting.
8. Polish compact layouts and verify iPhone, iPad, and Mac Catalyst behavior.

Each slice should be committed separately after verification.
