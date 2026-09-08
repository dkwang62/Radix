# Page Deletion Validation

This standalone probe compiles the production `PageDeletionJournal`,
`SentenceLibraryStore`, study models and `RadixPreferences` adapter. It has its
own bundle ID (`com.desmond.radix.deletionqa`), preference suites and synthetic
files. It never opens Radix's application container, databases or preferences.
It is not included in the Radix application or its Swift package targets.

## Build And Run On Mac

Requires XcodeGen and Xcode. From the repository root, run each command:

```sh
mkdir -p .build/PageDeletionProbe
xcodegen generate --spec Tests/PageDeletionProbe/project.yml --project-root .build/PageDeletionProbe --project .build/PageDeletionProbe
xcodebuild -quiet -project .build/PageDeletionProbe/PageDeletionProbe.xcodeproj -scheme PageDeletionProbeCLI -configuration Release -derivedDataPath .build/PageDeletionProbe/DerivedData CODE_SIGNING_ALLOWED=NO build
ruby Tests/PageDeletionProbe/run_host.rb .build/PageDeletionProbe/DerivedData/Build/Products/Release/PageDeletionProbeCLI
```

The runner launches a separate process for each interruption and another for
recovery. It requires actual SIGKILL termination, successful recovery, retained
favorites/shared sentences/progress/notes, correct descendant/artifact/image
removal and idempotent replay. It exercises seven boundaries: before intent,
after journal flush, after SQLite commit, between the two preference flushes,
after both preference flushes, after one image removal and after all images.
Each process has a 60-second timeout. Failed fixtures remain for diagnosis;
successful fixtures and their isolated preference domains are removed.

Nine performance samples cover three library sizes, three fresh fixtures each.
Each page contains 100 character entries, about 1.2 KB of OCR text and 1.2 KB of
cleaned text; there are ten sentences per page. The deletion removes one root
and two corrected children, with three 2 MB image files. An unrelated fourth
image must survive. These files exercise unlinking, not JPEG decoding.
Setup and verification are outside the timer; SQLite is warm from fixture
creation. The real app's navigation, rendering, script conversion and disk-full
behavior are not measured. `sqlite` is a subset of the `sentences` stage;
the `journal` stage includes preflight preference processing and durable intent.
Do not add those overlapping timings together.

## Physical Device

Build the `PageDeletionProbe` scheme for a paired device with signing enabled,
using a separate derived-data directory. Install the generated QA app with
`xcrun devicectl device install app`. The device must be unlocked and support
the installed developer disk image. Use a new UUID for each fixture.

```sh
xcrun devicectl device process launch --device DEVICE --console com.desmond.radix.deletionqa interrupt RUN_UUID journal
xcrun devicectl device process launch --device DEVICE --console com.desmond.radix.deletionqa recover RUN_UUID
xcrun devicectl device process launch --device DEVICE --console com.desmond.radix.deletionqa benchmark NEW_RUN_UUID 1000
```

Repeat the interrupt/recover pair for the seven boundaries above; their command
names are `before`, `journal`, `sentences`, `first-preference-store`,
`preferences`, `first-image`, and `images`. The intentional SIGKILL is expected;
the subsequent process must print `"result":"passed"`. The app exits after each
command. An ordinary launch with no arguments exits with a usage error.

With the QA app installed and the device unlocked, the complete device matrix is:

```sh
ruby Tests/PageDeletionProbe/run_device.rb DEVICE
```

The runner checks `terminationResult.terminatingSignal == 9` in devicectl's
structured JSON output. The probe waits after sending SIGKILL so delayed signal
delivery cannot accidentally become a normal process exit. It verifies all
seven recovery cases and collects three timing samples at each library size.

Device probe success does not sign off the actual Radix UI. A person must still
test the exact installed Radix build: cancel/confirm deletion in Capture, Browse
and Study; force-quit/relaunch; verify remaining favourites and pages; and check
Retry, touch responsiveness and navigation on iPhone/iPad. Full-backup restore
crash recovery and abrupt hardware power loss are outside this probe's scope.
