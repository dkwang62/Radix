# Repository Instructions for Coding Agents

## Context discipline

Use `PROJECT_CONTEXT.md` as the current architecture and workstream source of
truth, but do not read the whole file by default. First use targeted `rg`
searches and read only the relevant sections. Read more of it only when the task
touches architecture, persistence, navigation, release state, or a cross-cutting
feature.

Read `UI_INTENT.md` before navigation, layout, iPad/iPhone adaptation, or
UI-structure work. For small non-UI fixes, do not load it unnecessarily.

## Documentation retention

Documentation is operating memory for coding agents. Keep only material that
changes how an agent should understand, modify, verify, release, or describe the
current product. Preserve current architecture, durable contracts, UI intent,
reproducible probe instructions/results, release gates, licensing, and
publication source copy.

After a plan, audit, migration, or investigation is complete, fold its durable
conclusions and remaining actions into `PROJECT_CONTEXT.md`, tests, or the
relevant contract document, then delete the narrative file. Do not retain
session diaries or duplicate historical summaries; Git history is the archive.

## Token discipline

- Inspect only the files needed for the current task. Prefer `rg` and targeted
  reads over opening whole folders or large JSON/database-derived files.
- Summarize long command output. Do not paste full build logs unless the exact
  error text matters.
- Avoid broad refactors unless the user explicitly asks for them. Preserve
  working behavior and make the smallest coherent change.
- When diagnosing, explain the cause before implementing a fix unless the user
  has clearly asked for the fix.
- Avoid recreating Radix features with weak substitutes. Real stroke-order
  animation, character cards, phrase cards, and sentence data should come from
  the app’s existing data and UI paths where possible.

## Radix app expectations

For every completed work unit:

- update `PROJECT_CONTEXT.md` in the same commit;
- keep it concise and current rather than appending a long activity log;
- run the verification listed there;
- preserve persisted identifiers and cross-platform behavior unless the task
  includes an explicit migration;
- commit each coherent, verified unit separately.

For a TestFlight or release candidate, follow `TESTFLIGHT_RELEASE_CHECKLIST.md`.
Do not describe a candidate as release-ready until a person has completed the
physical-iPad gate for that exact version, build, and commit.

Git history is the detailed audit trail. `PROJECT_CONTEXT.md` is the hand-off.

<!-- personal-librarian-context:start -->
## Current project handoff

This section is maintained by Personal Librarian so work can continue on another Mac.

**Goal**

Add support for FreeLLMAPI as an OpenAI-compatible custom AI backend for Radix automatic AI execution, while preserving the existing Gemini path and manual AI fallback.

**Current State**

Radix currently has a shared AI workflow with manual copy/open handoff, template editing/testing, optional automatic Gemini execution, and paste/apply behavior.

Relevant files verified:

- `PROJECT_CONTEXT.md` has the AI contract: automatic Gemini is optional and manual fallback must remain.
- `ViewModels/RadixAIProviderState.swift` already stores `customURLString`, `customAIAPIKey`, provider API keys, and `geminiModelID`.
- `ViewModels/RadixStore.swift` exposes persisted accessors for custom AI URL/key and Gemini settings.
- `ViewModels/RadixStorePrompts.swift` loads/persists custom AI URL/key via `UserDefaults`.
- `Services/GeminiClient.swift` contains Gemini-specific request formatting and response parsing.
- `ViewModels/RadixStoreAI.swift` currently calls `GeminiPhraseExtractionService` and `GeminiTextGenerationService` for automatic AI work.

No implementation for FreeLLMAPI/OpenAI-compatible chat completions was found. Worktree was clean when checked.

**Decisions**

Implement FreeLLMAPI as a generic OpenAI-compatible client rather than modifying `GeminiClient`.

Likely shape:

- Add a new service beside `GeminiClient`, e.g. `OpenAICompatibleClient`.
- Use `customAIURLString` as the base URL, targeting `/v1/chat/completions`.
- Use `customAIAPIKey` as the bearer token.
- Default model can be `"auto"` for FreeLLMAPI unless/until Radix adds a custom model setting.
- Keep Gemini as the existing known-good automatic execution path.
- Keep manual fallback available for all automatic failures.

Avoid treating FreeLLMAPI as a production default for App Store users; it is better as a custom/power-user backend.

**Verification**

Read-only verification performed:

- Searched for AI/provider/client references.
- Inspected the AI contract section of `PROJECT_CONTEXT.md`.
- Inspected AI provider state, persistence, Gemini client, and Gemini call sites.
- Confirmed no repo changes were made.
- Confirmed `git status --short` produced no changes.

**Next Steps**

1. Add `Services/OpenAICompatibleClient.swift`.
2. Implement chat-completions request/response handling, including useful user-facing errors.
3. Wire automatic AI execution to select the OpenAI-compatible path when the configured/default provider is custom and URL/key are present.
4. Preserve Gemini behavior and manual fallback.
5. Add focused tests for URL normalization, request shape, response parsing, and fallback behavior.
6. Update `PROJECT_CONTEXT.md` with the durable architecture change after implementation.
<!-- personal-librarian-context:end -->
