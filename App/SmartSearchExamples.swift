import SwiftUI

extension SmartSearchTab {
    var searchExamplesAndHelp: some View {
        VStack(spacing: 14) {
            VStack(alignment: .leading, spacing: 12) {
                Text("Search by English")
                    .font(ResponsiveFont.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    SearchExampleButton(label: "=water ->", query: "水") { _ in
                        localQuery = "=water"
                        runSearch("=water")
                    }
                    SearchExampleButton(label: "watery ->", query: "含水") { _ in
                        localQuery = "watery"
                        runSearch("watery")
                    }
                }

                Text("Search by Pinyin")
                    .font(ResponsiveFont.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    SearchExampleButton(label: "shui ->", query: "水") { _ in
                        localQuery = "shui"
                        runSearch("shui")
                    }
                    SearchExampleButton(label: "hanshui ->", query: "含水") { _ in
                        localQuery = "hanshui"
                        runSearch("hanshui")
                    }
                }

                Text("Search by Apple IME Strokes")
                    .font(ResponsiveFont.subheadline)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    SearchExampleButton(label: "ノ丶丶フ丨 ->", query: "含") { _ in
                        localQuery = "ノ丶丶フ丨"
                        runSearch("ノ丶丶フ丨")
                    }
                    SearchExampleButton(label: "丨フノ丶 ->", query: "水") { _ in
                        localQuery = "丨フノ丶"
                        runSearch("丨フノ丶")
                    }
                }
            }
            .padding(isRunningOnMac ? 20 : 14)
            .background(Color(.secondarySystemBackground).opacity(0.5))
            .clipShape(RoundedRectangle(cornerRadius: 16))
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
                    Label("Show IME Chinese Strokes examples", systemImage: "keyboard")
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
                    Label("Show keyboard setup", systemImage: "gearshape")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            }
            .padding(isRunningOnMac ? 14 : 10)
            .frame(maxWidth: isRunningOnMac ? 760 : .infinity)
            .background(Color(.secondarySystemBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 16))
        }
        .frame(maxWidth: .infinity)
        .padding(.top, isRunningOnMac ? 40 : 12)
    }
}
