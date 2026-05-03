import SwiftUI

struct ComponentsRootsPopover: View {
    @EnvironmentObject private var store: RadixStore
    let character: String
    @Binding var selectedComponent: String?
    @State private var results: [ComponentItem] = []
    @State private var resultsTotal: Int = 0
    @State private var previewItem: ComponentItem?

    private var activeComponent: String {
        selectedComponent ?? character
    }

    private var title: String {
        "Contains \(activeComponent)"
    }

    private var gridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 48, maximum: 56), spacing: 6)]
    }

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        popoverContent
            .padding(isPhone ? 18 : 14)
            .frame(
                minWidth: isPhone ? 0 : 700,
                maxWidth: popoverMaxWidth,
                minHeight: isPhone ? 0 : 120,
                maxHeight: isPhone ? .infinity : 560,
                alignment: .topLeading
            )
            .onAppear {
                load(component: activeComponent)
            }
            .onChange(of: character) { _, _ in
                selectedComponent = character
                load(component: character)
            }
            .onChange(of: selectedComponent) { _, _ in
                load(component: activeComponent)
            }
            .onChange(of: store.scriptFilter) { _, _ in
                load(component: activeComponent)
            }
            .onChange(of: store.rootMinStroke) { _, _ in
                load(component: activeComponent)
            }
            .onChange(of: store.rootMaxStroke) { _, _ in
                load(component: activeComponent)
            }
            .onChange(of: store.rootRadicalFilter) { _, _ in
                load(component: activeComponent)
            }
            .onChange(of: store.rootStructureFilter) { _, _ in
                load(component: activeComponent)
            }
    }

    @ViewBuilder
    private var popoverContent: some View {
        if isPhone {
            VStack(alignment: .leading, spacing: 12) {
                componentResultsContent
                    .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                if let item = previewItem {
                    Divider()
                    LightweightCharacterPreviewCard(
                        item: item,
                        showsCloseButton: item.character != activeComponent
                    ) {
                        previewItem = store.item(for: activeComponent)
                    }
                    .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        } else {
            HStack(alignment: .top, spacing: 12) {
                componentResultsContent
                    .frame(width: 470, alignment: .topLeading)
                if let item = previewItem {
                    Divider()
                    LightweightCharacterPreviewCard(item: item, showsCloseButton: item.character != activeComponent) {
                        previewItem = store.item(for: activeComponent)
                    }
                }
            }
        }
    }

    private var componentResultsContent: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\(title) (\(resultsTotal))")
                .font(isPhone ? ResponsiveFont.title3.weight(.bold) : ResponsiveFont.headline)
            resultsGrid
        }
    }

    private var popoverMaxWidth: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 720
        #else
        if isPhone {
            return .infinity
        }
        return 720
        #endif
    }

    @ViewBuilder
    private var resultsGrid: some View {
        if results.isEmpty {
            Text("Not present in other characters.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.top, 2)
        } else {
            ScrollView {
                LazyVGrid(columns: gridColumns, spacing: 6) {
                    ForEach(results, id: \.character) { item in
                        ComponentCharacterTile(item: item, isCompact: true) {
                            store.speakCharacter(item.character)
                            store.pushRootBreadcrumb(item.character)
                            previewItem = item
                        }
                    }
                }
                .padding(.vertical, 2)
            }
            .frame(maxHeight: isPhone ? .infinity : 420)
        }
    }

    private func load(component: String) {
        let target = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !target.isEmpty else { return }
        let result = store.rootDerivatives(for: target)
        results = result.items
        resultsTotal = result.total
        if previewItem == nil || previewItem?.character != target {
            previewItem = store.item(for: target)
        }
    }
}
