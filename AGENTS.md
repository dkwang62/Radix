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

Use FreeLLMAPI with Radix as the configured OpenAI-compatible Custom AI backend for automatic AI execution, while preserving the existing Gemini automatic path and manual AI fallback.

## Current state

Radix has a shared AI workflow covering template editing/testing, manual copy/open handoff, optional automatic execution, and paste/apply behavior.

FreeLLMAPI/OpenAI-compatible support is implemented and committed:

- `e370f0d` adds the OpenAI-compatible client, request/response models, provider selection, and focused tests.
- `cae3ee1` fixes automatic AI configuration guards.
- `663e583` completes provider-neutral Automatic AI UI wording and iconography.
- `PROJECT_CONTEXT.md` documents that Gemini remains the default direct backend, while Custom AI can run automatic tasks through an OpenAI-compatible `/v1/chat/completions` endpoint such as FreeLLMAPI using model `auto`.

Local FreeLLMAPI setup:

- Repository: `/Users/desmondkwang/Developer/freellmapi`
- Dashboard: `http://127.0.0.1:3001`
- Radix Custom AI URL: `http://127.0.0.1:3001/v1`
- Radix Custom AI API key: `freellmapi-e4b60d507b8dd44b5d99efde671dcb9f69aab48f39c29ce0`
- First-run setup code printed by FreeLLMAPI: `RN9FJZD9WS`
- Launch agent: `/Users/desmondkwang/Library/LaunchAgents/co.freellmapi.local.plist`
- Logs: `/Users/desmondkwang/Developer/freellmapi/logs/freellmapi.out.log`
- Error logs: `/Users/desmondkwang/Developer/freellmapi/logs/freellmapi.err.log`

Radix host defaults have been written for bundle `com.desmond.radix`:

- `radix.defaultAIPreset = custom`
- `radix.customAIURL = http://127.0.0.1:3001/v1`
- `radix.customAIAPIKey = freellmapi-e4b60d507b8dd44b5d99efde671dcb9f69aab48f39c29ce0`

If Radix is run in an iOS Simulator or on a physical device with a separate app container, the same URL and API key may still need to be entered in Radix Settings.

## Verification

Radix verification passed after the FreeLLMAPI implementation:

- `swift test`
- `xcodebuild -project Radix.xcodeproj -scheme Radix -destination 'generic/platform=iOS Simulator' build`

FreeLLMAPI local verification passed:

- `npm install` completed with Node engine warnings because the system Node is `v25.9.0`; FreeLLMAPI declares `>=20.18 <25`.
- `npm run build` completed successfully.
- Authenticated `GET /v1/models` succeeded and returned `279` models with `auto` first.
- `launchctl print gui/$(id -u)/co.freellmapi.local` showed the service running.

## Next steps

1. Open the FreeLLMAPI dashboard at `http://127.0.0.1:3001`.
2. Create the first admin account, using setup code `RN9FJZD9WS` if the dashboard asks for it.
3. Add at least one provider key in FreeLLMAPI, such as Groq, Cerebras, Google AI Studio, Mistral, NVIDIA, or OpenRouter.
4. In Radix, confirm Settings shows Custom AI URL `http://127.0.0.1:3001/v1` and the API key above, especially when testing in Simulator or on device.
5. Run a Radix automatic AI task; manual fallback must remain available for any provider failure.
<!-- personal-librarian-context:end -->
