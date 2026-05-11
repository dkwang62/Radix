import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct ComponentsExplorerShell: View {
    @EnvironmentObject var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var seed: String = ""
    @State var showRootFilters = false
    @State var expandedComponents: Set<String> = []
    @State var derivativesExpanded: Bool = false
    var seedOverride: String?

    var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    var hasRootContext: Bool {
        seedOverride != nil || store.previewCharacter != nil || !seed.isEmpty
    }

    var body: some View {
        #if targetEnvironment(macCatalyst)
        let isPhone = false
        #else
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #endif

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
        .navigationTitle("Components")
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
        #if targetEnvironment(macCatalyst)
        .onChange(of: store.previewCharacter) { _, newValue in
            syncSeed(with: newValue, resetHistory: false)
        }
        #else
        .onChange(of: store.previewCharacter) { _, newValue in
            if UIDevice.current.userInterfaceIdiom != .phone {
                syncSeed(with: newValue, resetHistory: false)
            }
        }
        #endif
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
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)

            Spacer()
        }
        .padding(.bottom, 4)
    }

    @ViewBuilder
    var gridInteractionHintRow: some View {
        HStack(spacing: 10) {
            hintChip(icon: "cursorarrow", text: isRunningOnMac ? "Click Preview" : "Tap Preview")
            hintChip(icon: "bookmark", text: "Preview adds to 🕘")
            HStack(spacing: 4) {
                Text(isRunningOnMac ? "Right-click" : "Long-press")
                Image(systemName: "doc.on.doc")
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
    }

    func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    @ViewBuilder
    var helpSection: some View {
        if store.showComponentHelp {
            VStack(alignment: .leading, spacing: 4) {
                Text("How to use Components Explorer")
                    .font(ResponsiveFont.subheadline.bold())
                Text("Link characters through a shared component: start from a familiar character, tap a component to pivot, view characters built with that part, and keep pivoting until you find the one you need.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 4)
        }
    }
}
