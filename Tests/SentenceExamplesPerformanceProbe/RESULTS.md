# Sentence Examples Performance Results

Date: 2026-09-09

The release-built isolated QA bundle ran three fresh fixtures at each library
size on each physical iPhone. Every benchmark launched in a new process after
seeding. The measured path used production `SentenceLibraryStore` queries and
the shipping candidate-offset exact paging algorithm. Fixture creation was
outside the page timers.

| Device | Sentences | First 24 rows (median) | Second page | Third page | Largest frame interval |
| --- | ---: | ---: | ---: | ---: | ---: |
| iPhone 13 mini, iOS 26.5.2 | 10,000 | 27.6 ms | 14.0 ms | 11.9 ms | 16.7 ms |
| iPhone 13 mini, iOS 26.5.2 | 50,000 | 66.7 ms | 30.3 ms | 23.9 ms | 16.7 ms |
| iPhone 16e, iOS 26.6.1 | 10,000 | 21.7 ms | 11.8 ms | 10.5 ms | 16.7 ms |
| iPhone 16e, iOS 26.6.1 | 50,000 | 54.0 ms | 27.5 ms | 18.3 ms | 16.7 ms |

All 12 runs returned complete, non-overlapping 24-row pages and the expected
corpus total. The slower tested device returned the first page from a 50,000-
sentence library in under 67 ms. Because the query ran on the shipping sheet's
user-initiated worker path, the main-thread display link did not miss a frame.

This validates the physical-device large-corpus query-responsiveness contract.
It does not certify visual row rendering, scrolling, Dynamic Type, or
accessibility in the full shipping Radix UI; those remain part of the
physical-device release matrix.
