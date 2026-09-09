# Radix

Radix is a native SwiftUI Chinese learning workspace for iPhone, iPad, and Mac
Catalyst. It turns Chinese encountered in daily life into saved pages,
dictionary inspection, AI-assisted understanding, Study practice, and portable
learning memory.

The product loop is:

```text
Scan -> Review -> Practise -> Keep
```

The current architecture and workflow source of truth is `PROJECT_CONTEXT.md`.
Read `UI_INTENT.md` before changing navigation, tab structure, Browse, Study,
AI, My Data, or other user-facing workflow structure.

## Canonical Documentation

- `AGENTS.md` — repository instructions for coding agents.
- `PROJECT_CONTEXT.md` — current architecture, product direction, data rules,
  workstream posture, and required verification.
- `UI_INTENT.md` — UI/product intent and design decision rules.
- `PORTABLE_BACKUP_FORMAT.md` — portable backup bundle and JSON payload
  contract.
- `RADIX_UI_AUDIT.md` — completed hostile-QA findings, remediation status, and
  remaining adversarial test matrix.
- `TESTFLIGHT_RELEASE_CHECKLIST.md` — build-specific automated and physical-iPad
  release gate.
- `VARIANT_MEANING_MIGRATION_2026-08-22.md` — audit for the completed one-time
  dictionary meaning migration.
- `APP_STORE_COPY.md` — App Store and marketing copy draft.
- `THIRD_PARTY_LICENSES.md` — bundled data/source license summary.

Historical plan/status files have been removed once their completed decisions
were folded into the canonical docs. Git history remains the audit trail.

## Third-Party Licenses

- Radix includes a Credits / Data Sources screen in Settings.
- Radix attributes CC-CEDICT data (CC BY-SA 4.0): https://cc-cedict.org/
- Radix attributes Unicode/Unihan/IDS references: https://www.unicode.org/
- Radix includes HanziWriter JavaScript under the MIT License.
- Radix includes HanziWriter-compatible stroke data derived from Make Me a Hanzi / Arphic data under the Arphic Public License.
- Full license texts are bundled in `Resources/Licenses/` and summarized in `THIRD_PARTY_LICENSES.md`.

## Naming Notes

- Some internal model, route, and persistence names still use older terms such
  as `favourites`, `lineage`, `breadcrumb`, or `rootBreadcrumb` for backward
  compatibility. Do not rename those identifiers unless you also migrate saved
  data and route handling.
- The user-facing memory strip is called History in the app.

## Hosted Animation Links

- `animate.html` is a static HanziWriter player intended for GitHub Pages.
- Public links use `https://dkwang62.github.io/Radix/animate.html?char=水`.
- The hosted player first checks Radix-published JSON files in `strokes/u<codepoint>.json`, then falls back to HanziWriter's public CDN.
- To publish app-generated strokes for characters missing from HanziWriter, preview the character in the app, then run `ruby Scripts/export_generated_strokes.rb` and commit/push the generated `strokes/*.json` files.
- GitHub Pages must be enabled for the repository before those links work for external users.
- The page intentionally displays only the animated character.

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

- Before making navigation or UI-structure changes, read `UI_INTENT.md`. It
  records the intended Radix product model for global Search, Camera, Browse,
  Study, AI, My Data, and recovery workflows.
- `project.yml` bundles data directly from:
  - `../enhanced_component_map_with_etymology.json`
  - `../phrases.db`
  - `../SUBTLEX-CH-CHR.txt`
- If you move files, update these paths in `project.yml`.
- `Resources/Assets.xcassets` is included with `AppIcon` and `AccentColor` entries.

## TestFlight Prep

Current project defaults now include:

- `MARKETING_VERSION = 1.0.6`
- `CURRENT_PROJECT_VERSION = 9`
- `ITSAppUsesNonExemptEncryption = NO`
- Universal target family (`TARGETED_DEVICE_FAMILY = 1,2`)

Before shipping to TestFlight:

1. Complete a fresh [TestFlight release checklist](TESTFLIGHT_RELEASE_CHECKLIST.md)
   for the exact version, build, and commit being uploaded.
2. Verify bundle identifiers and signing ownership in `project.yml` and Xcode.
3. Set your Apple Team in Xcode Signing & Capabilities.
4. Verify the production AppIcon set in `Resources/Assets.xcassets/AppIcon.appiconset`.
5. Archive from Xcode (`Product > Archive`) and validate/upload only after the
   automated and physical-iPad gates pass.
