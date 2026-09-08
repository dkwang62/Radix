# Deletion Validation Results

Date: 2026-09-08. Probe source: `06aceb0`. Apple M4, macOS 26.6.2 (25G83),
Release optimization. Production application behavior was not changed during
this validation work. See README.md for fixture design and reproduction.

## Process Interruption

All seven separate-process SIGKILL/relaunch cases passed:

- Before journal creation: the complete original library remains.
- After durable journal creation.
- After SQLite reconciliation commits.
- Between application and study preference-store flushes.
- After both preference-store flushes.
- After deleting the first image.
- After deleting all images, before retiring the journal.

Each recovery checks exact surviving page IDs, artifacts, practice packs,
favorite/shared sentence retention, provenance, selected page/topic, independent
notes/progress and image presence. A second recovery must leave that state intact.
The probe uses actual UserDefaults suites and the production flush adapter.

## Timing

Final run, three fresh fixtures per size; setup and verification excluded:

| Pages | Sentences | Median deletion | Observed range |
| --- | --- | --- | --- |
| 100 | 1,000 | 26.9 ms | 26.7-27.3 ms |
| 1,000 | 10,000 | 242.3 ms | 240.9-254.5 ms |
| 5,000 | 50,000 | 1,206.8 ms | 1,130.9-1,217.0 ms |

Empty-journal recovery averaged 0.0031-0.0037 ms over 1,000 calls per fixture.
Actual restart recovery for the 100-page fixture took 18.8-23.2 ms, excluding
process launch; the before-intent no-op took about 0.003 ms.

This is a warm synthetic library and a three-page cascade, not an iPhone/iPad
UI benchmark or a worst-case bulk deletion. At 50,000 sentences, SQLite source
reconciliation alone took 550-567 ms. `reconcileSources` fetches and decodes the
entire corpus. Preference preflight and replay also serialize full collections.
`RadixStore.deleteCollection` runs synchronously on the main actor, so these
durations imply a noticeable pause at large sizes. The previous estimate of
negligible deletion latency is not supported for large libraries.

Recommendation: address the measured full-corpus scan and repeated preference
processing before expanding to backup-restore journaling. Preserve journal
ordering, failure behavior and mutation serialization while doing so.

## Physical Device And Build Status

- Signed iOS probe built and installed as the separate Radix Deletion QA app on
  an iPhone 13 mini (iOS 26.5.2). Launch was rejected by iOS with `Locked`.
- Paired iPad 9th generation initially failed to mount its developer disk image;
  it was unavailable during the later connection check.
- Physical-device interruption, device timing and actual Radix touch/navigation
  checks remain pending. No physical release sign-off is claimed.
- Full `swift test`: 169 tests in 15 suites passed.
- Mac Catalyst application build with signing disabled: passed.
- Release Mac probe and signed iOS probe builds: passed.
- `git diff --check`: passed.

Full-backup restore crash recovery and hardware power-loss guarantees remain
outside this validation. Successful probe fixtures clean up their own data.
