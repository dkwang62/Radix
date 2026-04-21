# Radix

Native multi-platform SwiftUI version of the existing Streamlit Radix app.

## Included

- `project.yml` (XcodeGen spec for the Radix Xcode target)
- SwiftUI app shell with iPhone, iPad, and Mac Catalyst layouts
- JSON loader for `enhanced_component_map_with_etymology.json`
- SQLite reader for `phrases.db`
- Search by character/pinyin/definition
- Search modes:
  - Smart search (character/pinyin/meaning)
  - Definition search (character + phrase meaning lookup)
- Script filter (`简` / `繁`)
- Standard tab headers across platforms:
  - `Search`
  - `Browse`
  - `Roots`
  - `Favorites`
  - `AI Link`
  - `My Data`
- Remembered bar:
  - Temporary session memory shown at the top of the app
  - `Remember` adds a character to the bar
  - Favorites persist after the app closes
- Roots section:
  - Components parsed from decomposition
  - Derivatives from related characters
  - Semantic/phonetic hints for ⿰ / ⿱ structures
- Roots pagination (`25` per batch) and sort mode (`Usage` / `Frequency`)
- Full-screen Roots Explorer for deep drill-down
- Related character browsing
- Stroke-order animation section (HanziWriter in-app web view)
- Phrase list by selected character (2/3/4 char)
- Rich phrase cards with focus-character highlighting
- Favorites persisted in `UserDefaults`
- Profile import/export as JSON (`schema_version: 1`)
- Paywall policy:
  - Most app features are free
  - `My Data` advanced editing/export features require Pro

## Naming Notes

- The visible UI uses `Favorites`, `Roots`, and `Remembered`.
- Some internal model, route, and persistence names still use `favourites`, `lineage`, or `breadcrumb` for backward compatibility. Do not rename those identifiers unless you also migrate saved data and route handling.
- The Remembered bar was historically implemented as `rootBreadcrumb`; it is now the global temporary character memory bar.

## Create the Xcode project

1. Install full Xcode from the App Store.
2. Point developer tools to Xcode:
   - `sudo xcode-select -s /Applications/Xcode.app/Contents/Developer`
3. Install XcodeGen:
   - `brew install xcodegen`
4. From `Radix/`, generate the project:
   - `xcodegen generate`
5. Open `Radix.xcodeproj` in Xcode.
6. Select an iPhone, iPad, or Mac-compatible simulator and run.

## Notes

- `project.yml` bundles data directly from:
  - `../enhanced_component_map_with_etymology.json`
  - `../phrases.db`
  - `../SUBTLEX-CH-CHR.txt`
- If you move files, update these paths in `project.yml`.
- `Resources/Assets.xcassets` is included with `AppIcon` and `AccentColor` entries.

## TestFlight Prep

Current project defaults now include:

- `MARKETING_VERSION = 1.0.0`
- `CURRENT_PROJECT_VERSION = 1`
- `ITSAppUsesNonExemptEncryption = NO`
- Universal target family (`TARGETED_DEVICE_FAMILY = 1,2`)

Before shipping to TestFlight:

1. Set your real bundle ID in `project.yml` (`PRODUCT_BUNDLE_IDENTIFIER`).
2. Set your Apple Team in Xcode Signing & Capabilities.
3. Add real AppIcon image files in `Resources/Assets.xcassets/AppIcon.appiconset`.
4. Archive from Xcode (`Product > Archive`) and validate/upload.
