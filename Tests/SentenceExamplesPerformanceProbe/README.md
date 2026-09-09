# Sentence Examples Performance Validation

This standalone iOS probe measures exact sentence-example paging against the
production `SentenceLibraryStore`. It has a separate bundle ID and
stores synthetic sentence databases only in its own application container. It
does not open Radix data.

Each benchmark uses a cold process after seeding and records three consecutive
24-row exact pages for the common character `的`. A `CADisplayLink` records the
largest main-thread frame interval while paging runs on a user-initiated worker,
matching the shipping sheet's off-presentation execution model. Fixture setup is
reported separately and is not part of page latency.

Generate and build the project, install it on an unlocked paired device, then
run three fresh 10,000- and 50,000-sentence fixtures:

```sh
mkdir -p .build/SentenceExamplesPerformanceProbe
xcodegen generate \
  --spec Tests/SentenceExamplesPerformanceProbe/project.yml \
  --project-root .build/SentenceExamplesPerformanceProbe \
  --project .build/SentenceExamplesPerformanceProbe
xcodebuild -quiet \
  -project .build/SentenceExamplesPerformanceProbe/SentenceExamplesPerformanceProbe.xcodeproj \
  -scheme SentenceExamplesPerformanceProbe \
  -configuration Release \
  -destination 'generic/platform=iOS' \
  -derivedDataPath .build/SentenceExamplesPerformanceProbe/DerivedData \
  -allowProvisioningUpdates build
xcrun devicectl device install app --device DEVICE \
  .build/SentenceExamplesPerformanceProbe/DerivedData/Build/Products/Release-iphoneos/SentenceExamplesPerformanceProbe.app
ruby Tests/SentenceExamplesPerformanceProbe/run_device.rb DEVICE
```

This validates physical-device storage/query cost and absence of a query-caused
main-thread stall. It does not replace human inspection of the shipping sheet's
row rendering, scrolling, or accessibility.
