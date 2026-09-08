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

The later unlocked-device run completed on both devices. Each passed all seven
SIGKILL/relaunch cases and all nine timing runs using the isolated QA app:

| Device | 100 pages / 1K sentences | 1K pages / 10K sentences | 5K pages / 50K sentences |
| --- | --- | --- | --- |
| iPhone 13 mini, iOS 26.5.2 | 35.2 ms | 312.7 ms | 1,662.8 ms |
| iPad 9th generation, iPadOS 26.6.1 | 56.5 ms | 474.7 ms | 2,388.3 ms |

Values are medians of three deletion runs. Observed 5K-page ranges were
1,623.8-1,692.1 ms on iPhone and 2,332.9-2,457.3 ms on iPad. Recovery for the
100-page fixture took 35.6-40.6 ms on iPhone and 44.4-57.0 ms on iPad, excluding
the before-intent no-op and application launch. Empty-journal checks averaged
0.052-0.060 ms on iPhone and 0.055-0.067 ms on iPad.

The device probe waits for SIGKILL delivery rather than falling through to a
normal exit. An initial normal-exit attempt was rejected and rerun. The device
runner requires signal 9 in devicectl's structured termination result and checks
the next launch's invariant report. The corrected probe also passed all seven
Mac interruption cases and nine Mac timing runs again.

Tested signed iOS executable SHA-256:
`47b2b6f0220c8303eb5f6e2fab16a70dac37bd503c50854853ea0a899d56b1d4`.

The measurements confirm a noticeable large-library pause. They measure the
production storage code inside a probe, not actual Radix frame pacing. A person
still needs to exercise the exact shipping Radix build's touch, navigation,
confirmation/cancellation, Retry and background/foreground behavior. No release
sign-off is claimed. Temporary QA apps were removed; Radix data was untouched.

- Full `swift test`: 169 tests in 15 suites passed.
- Mac Catalyst application build with signing disabled: passed.
- Release Mac probe and signed iOS probe builds: passed.
- `git diff --check`: passed.

Full-backup restore crash recovery and hardware power-loss guarantees remain
outside this validation. Successful probe fixtures clean up their own data.
