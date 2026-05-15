import SwiftUI

extension SmartSearchTab {
    var searchExamplesAndHelp: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Search by example", systemImage: "sparkle.magnifyingglass")
                    .font(ResponsiveFont.headline)

                LazyVGrid(columns: [GridItem(.adaptive(minimum: isRunningOnMac ? 150 : 132), spacing: 8)], spacing: 8) {
                    SearchExampleButton(label: "Pinyin", query: "shui", desc: "水") { query in
                        localQuery = query
                        runSearch(query)
                    }
                    SearchExampleButton(label: "Meaning", query: "water", desc: "水") { _ in
                        localQuery = "=water"
                        runSearch("=water")
                    }
                    SearchExampleButton(label: "Phrase", query: "hanshui", desc: "含水") { query in
                        localQuery = query
                        runSearch(query)
                    }
                    SearchExampleButton(label: "Strokes", query: "ノ丶丶フ丨", desc: "含") { query in
                        localQuery = query
                        runSearch(query)
                    }
                    SearchExampleButton(label: "Strokes", query: "丨フノ丶", desc: "水") { query in
                        localQuery = query
                        runSearch(query)
                    }
                }
            }
            .padding(isRunningOnMac ? 20 : 14)
            .background(Color(.secondarySystemBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .frame(maxWidth: {
                #if targetEnvironment(macCatalyst)
                return 900
                #else
                return 550
                #endif
            }())

            VStack(alignment: .leading, spacing: 12) {
                DisclosureGroup(isExpanded: $showAppleStrokeHelp) {
                    VStack(alignment: .leading, spacing: 6) {
                        if isRunningOnMac {
                            AppleStrokeKeyMap()
                            AppleStrokeExamplesView()
                        } else {
                            AppleStrokeExamplesView(compact: true)
                        }
                    }
                } label: {
                    Label("Stroke input examples", systemImage: "keyboard")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

                DisclosureGroup(isExpanded: $showAppleSetupGuide) {
                    if isRunningOnMac {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("On Mac")
                                .font(ResponsiveFont.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Text("1. Apple menu > System Settings > Keyboard > Text Input > Edit.")
                            Text("2. Add Chinese, Simplified - Stroke or Chinese, Traditional - Stroke.")
                            Text("3. Switch to that input source from the menu bar.")
                            Text("4. Enter the component or character in the search field above.")
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
                    Label("Keyboard setup", systemImage: "gearshape")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            }
            .padding(isRunningOnMac ? 14 : 10)
            .frame(maxWidth: isRunningOnMac ? 760 : .infinity)
            .background(Color(.secondarySystemBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, isRunningOnMac ? 40 : 12)
    }
}
