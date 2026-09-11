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

## Goal

Add FreeLLMAPI support to Radix as an OpenAI-compatible custom AI backend for automatic AI execution, while preserving the existing Gemini automatic path and manual AI fallback.

## Current state

Radix has a shared AI workflow covering template editing/testing, manual copy/open handoff, optional automatic Gemini execution, and paste/apply behavior.

Relevant source state:

- `PROJECT_CONTEXT.md` states automatic Gemini is optional and must always retain manual fallback.
- `Models/UserProfile.swift` defines `DefaultAIPreset.custom` as “Custom AI”.
- `ViewModels/RadixAIProviderState.swift` already stores `customURLString`, `customAIAPIKey`, provider API keys, and `geminiModelID`.
- `ViewModels/RadixStore.swift` exposes persisted accessors for `customAIURLString`, `customAIAPIKey`, and Gemini settings.
- `ViewModels/RadixStorePrompts.swift` loads/persists custom AI URL/key via `UserDefaults`.
- `ViewModels/RadixStoreAI.swift` contains `normalizedCustomAIURL`, manual AI URL behavior, and Gemini-only automatic task methods.
- `Services/GeminiClient.swift` is Gemini-specific: request shape, API key header, endpoint, response parsing, and user-facing errors are all tied to Gemini.
- Automatic AI call sites currently invoke `runGemini...` methods directly.
- No `OpenAICompatibleClient`, `FreeLLMAPI`, or chat-completions client implementation is present.

## Decisions

Implement FreeLLMAPI through a generic OpenAI-compatible service rather than modifying `GeminiClient`.

Likely shape:

- Add a new service beside `Services/GeminiClient.swift`, e.g. `OpenAICompatibleClient`.
- Use `customAIURLString` as the configured base URL.
- Normalize base URLs so both `/v1` and host-only forms can target `/v1/chat/completions` correctly.
- Use `customAIAPIKey` as a bearer token.
- Default model can be `"auto"` unless Radix later adds a custom model setting.
- Keep Gemini as the existing known-good automatic provider.
- Keep manual fallback available for all automatic failures.

FreeLLMAPI should be treated as a custom/power-user backend, not as Radix’s production default.

## Verification

Read-only verification performed:

- Searched AI/provider/client references with `grep`/`find` because `rg` is unavailable in this shell.
- Inspected relevant snippets in `PROJECT_CONTEXT.md`, `Models/UserProfile.swift`, `ViewModels/RadixAIProviderState.swift`, `ViewModels/RadixStore.swift`, `ViewModels/RadixStorePrompts.swift`, `ViewModels/RadixStoreAI.swift`, and `Services/GeminiClient.swift`.
- Confirmed `git status --short` is clean.
- No repository changes were made.

## Next steps

1. Add `Services/OpenAICompatibleClient.swift`.
2. Implement OpenAI chat-completions request/response handling with useful user-facing errors.
3. Wire automatic AI execution to select the OpenAI-compatible path when the default provider is `.custom` and URL/key are present.
4. Preserve existing Gemini behavior and manual fallback behavior.
5. Add focused tests for URL normalization, request shape, response parsing, and provider selection/fallback behavior.
6. Update `PROJECT_CONTEXT.md` with the durable architecture change after implementation.
<!-- personal-librarian-context:end -->
