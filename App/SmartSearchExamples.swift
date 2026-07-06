import SwiftUI

extension SmartSearchTab {
    var searchExamplesAndHelp: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Search by example", systemImage: "sparkle.magnifyingglass")
                    .font(ResponsiveFont.headline)

                searchExampleButtons
            }
            .padding(isRunningOnMac ? 20 : 14)
            .background(RadixTheme.secondaryBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: {
                #if targetEnvironment(macCatalyst)
                return 900
                #else
                return 550
                #endif
            }())

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $showAppleSetupGuide) {
                    if isRunningOnMac {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("On Mac")
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("1. Apple menu > System Settings > Keyboard > Text Input > Edit.")
                            Text("2. Add Chinese, Simplified - Stroke or Chinese, Traditional - Stroke.")
                            Text("3. Switch to that input source from the menu bar.")
                            Text("4. Type strokes, choose the completed character from Apple’s candidate list, then search that character in Radix.")
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("On iPhone or iPad")
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("1. Go to Settings > General > Keyboard > Keyboards > Add New Keyboard.")
                            Text("2. Add Chinese, Simplified, Chinese, Traditional, or Chinese Handwriting.")
                            Text("3. Return to this app and tap the search field above.")
                            Text("4. Use Apple’s keyboard candidate bar to enter the component or character.")
                            Text("If you use a hardware keyboard, you can switch keyboards with Control-Space.")
                        }
                    }
                } label: {
                    Label("Chinese keyboard setup", systemImage: "keyboard")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            }
            .padding(isRunningOnMac ? 14 : 10)
            .frame(maxWidth: isRunningOnMac ? 760 : .infinity)
            .background(RadixTheme.secondaryBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, isRunningOnMac ? 40 : 12)
    }

    var searchExampleButtons: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                searchExampleButton(label: "Pinyin", query: "shui", desc: "水")
                searchExampleButton(label: "Exact meaning", query: "=water", desc: "water, not waterproof")
                searchExampleButton(label: "Phrase", query: "hanshui", desc: "含水")
            }

            VStack(spacing: 8) {
                searchExampleButton(label: "Pinyin", query: "shui", desc: "水")
                searchExampleButton(label: "Exact meaning", query: "=water", desc: "water, not waterproof")
                searchExampleButton(label: "Phrase", query: "hanshui", desc: "含水")
            }
        }
    }

    func searchExampleButton(label: String, query: String, desc: String) -> some View {
        SearchExampleButton(label: label, query: query, desc: desc) { query in
            localQuery = query
            runSearch(query)
        }
    }
}
