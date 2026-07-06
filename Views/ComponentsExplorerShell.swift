import SwiftUI

struct ComponentsExplorerShell: View {
    @EnvironmentObject var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var seed: String = ""
    @State var showRootFilters = false
    @State var expandedComponents: Set<String> = []
    @State var derivativesExpanded: Bool = false
    var seedOverride: String?

    var isRunningOnMac: Bool {
        RadixPlatform.isRunningOnMac
    }

    var hasRootContext: Bool {
        seedOverride != nil || store.previewCharacter != nil || !seed.isEmpty
    }

    var body: some View {
        let isPhone = RadixPlatform.isPhone

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 0).id("rootsTop")

                    if isPhone,
                       hasRootContext,
                       let current = store.previewCharacter,
                       store.item(for: current) != nil {
                        standardPhoneCharacterPreview(
                            character: current,
                            onClear: { store.previewCharacter = nil }
                        )
                        .padding(.bottom, 8)
                    }

                    explorerToolbar
                    gridInteractionHintRow
                    helpSection

                    if hasRootContext {
                        derivativesSection
                        sharedPeersSections
                    } else {
                        let initial = store.rootInitialGridItems()
                        initialRootGrid(items: initial.items, total: initial.total)
                    }
                }
                .padding()
            }
            .onChange(of: seed) { _, _ in
                withAnimation { proxy.scrollTo("rootsTop", anchor: .top) }
            }
            .onChange(of: store.previewCharacter) { _, _ in
                withAnimation { proxy.scrollTo("rootsTop", anchor: .top) }
            }
        }
        .navigationTitle("Character Breakdown")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if store.rootsReturnContext != nil {
                    Button {
                        store.returnFromRoots()
                    } label: {
                        Label(store.rootsReturnButtonTitle, systemImage: "chevron.backward")
                    }
                }
            }
        }
        .onAppear {
            let start = seedOverride ?? store.previewCharacter
            syncSeed(with: start, resetHistory: true)
        }
        .onDisappear {
            expandedComponents = []
            derivativesExpanded = false
        }
        .onChange(of: store.scriptFilter) { _, _ in reloadRootContextIfNeeded() }
        .onChange(of: store.rootMinStroke) { _, _ in reloadRootContextIfNeeded() }
        .onChange(of: store.rootMaxStroke) { _, _ in reloadRootContextIfNeeded() }
        .onChange(of: store.rootRadicalFilter) { _, _ in reloadRootContextIfNeeded() }
        .onChange(of: store.rootStructureFilter) { _, _ in reloadRootContextIfNeeded() }
        .onChange(of: store.previewCharacter) { _, newValue in
            if !RadixPlatform.isPhone {
                syncSeed(with: newValue, resetHistory: false)
            }
        }
        .sheet(isPresented: $showRootFilters) {
            rootFiltersSheet
        }
    }

    var explorerToolbar: some View {
        HStack(alignment: .center, spacing: 12) {
            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }

            Button {
                showRootFilters = true
            } label: {
                Label(rootFilterButtonTitle, systemImage: activeRootFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .radixSurface(RadixTheme.secondaryBackground, radius: 12)
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    var gridInteractionHintRow: some View {
        InteractionHintRow(
            previewText: isRunningOnMac ? "Click to preview" : "Tap to preview",
            memoryText: "Adds to Recent",
            copyText: isRunningOnMac ? "Right-click to copy" : "Long-press to copy"
        )
    }

    @ViewBuilder
    var helpSection: some View {
        if store.showComponentHelp {
            VStack(alignment: .leading, spacing: 4) {
                Text("Breakdown")
                    .font(ResponsiveFont.subheadline.bold())
                Text("Tap a component to pivot through related characters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
