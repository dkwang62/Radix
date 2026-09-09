# Radix TestFlight Release Checklist

Complete a fresh copy of this checklist for every TestFlight candidate. Do not
mark this tracked template as complete: record the result in the release commit,
task handoff, or release notes so an older sign-off cannot approve a newer build.

A candidate is not ready to upload until every automated check passes and the
physical-iPad checks have been completed for that exact version, build, and
commit. Codex may complete the automated section, but must report the physical
section as pending until a person tests the installed build.

## Candidate

- Version and build:
- Commit:
- Test date:
- Physical iPad model and iPadOS version:
- Tester:

## Automated Gate

- [ ] `git diff --check`
- [ ] `swift test`
- [ ] Mac Catalyst build
- [ ] Generic iOS Simulator build
- [ ] Generic iOS device build
- [ ] Version and build match in the app and share extension targets

## Physical iPad Gate

- [ ] Cold-launch Radix and switch through Browse, Study, AI, My Data, and
      Settings without a freeze, blank pane, or broken title menu.
- [ ] Capture or import a page and confirm that its Browse tiles appear, remain
      selectable, and open the expected information card.
- [ ] On that page, open and dismiss the page Actions and AI submenus, enter its
      Study page, and move between Browse and Study without losing the page.
- [ ] In Study Sentences, scroll, change pages, open a sentence card, use its
      context/AI menu, and dismiss every presented sheet.
- [ ] Open character and phrase information cards, exercise their menus and a
      sheet, and confirm the sidebar remains usable.
- [ ] Repeat the Browse-page and Study-Sentences checks in portrait and landscape.
- [ ] From Browse and Study, background and foreground Radix at least three
      times, including once with a menu or sheet open. Confirm the app remains
      responsive and preserves the current selection.
- [ ] Leave Radix in the background for at least one minute, reopen it, and
      confirm capture pages, menus, and Study navigation still work.
- [ ] At the largest supported Dynamic Type size, verify Study Sentences,
      Added Phrases, page controls, character/phrase cards, and New Saved Page
      remain readable and their primary actions remain reachable.
- [ ] With VoiceOver, verify the component-usage control, learning-tier guide,
      New Saved Page fields, destructive confirmations, and sheet dismissal;
      confirm focus returns to the initiating control.
- [ ] Create and return to a Checkpoint, then open My Data and preview a Backup.
      Confirm recovery progress, errors, and return paths do not strand the UI.

## Feature-Specific Gates

Complete these when the candidate changes the corresponding feature:

- [ ] StoreKit: unavailable-product retry, cancelled purchase, Ask to Buy or
      pending purchase, restore with no purchase, delayed completion, and
      subscription lapse in Apple's test environment.
- [ ] Restore/persistence: interruption on a disposable library, disk-full or
      injected write failure, Retry after relaunch, and large-backup timing.
- [ ] Capture/media: camera denial, limited Photos access, picker cancellation,
      large-image rejection, unusual EXIF orientation, and local-only OCR
      failure before explicit Gemini consent.

## Pass Or Stop

Pass only when there is no crash, watchdog termination, frozen interaction,
unreachable control, clipped primary content, or lost navigation context.

If any check fails, stop the release. Record the version/build, device/iPadOS,
time, active screen, exact actions, and whether a menu or sheet was open. Keep
the crash report or console log with the failure before changing code.
