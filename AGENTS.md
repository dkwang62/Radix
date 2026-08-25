# Repository Instructions for Coding Agents

## Context discipline

Use `PROJECT_CONTEXT.md` as the current architecture and workstream source of
truth, but do not read the whole file by default. First use targeted `rg`
searches and read only the relevant sections. Read more of it only when the task
touches architecture, persistence, navigation, release state, or a cross-cutting
feature.

Read `UI_INTENT.md` before navigation, layout, iPad/iPhone adaptation, or
UI-structure work. For small non-UI fixes, do not load it unnecessarily.

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
