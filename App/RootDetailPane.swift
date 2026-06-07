import SwiftUI

extension RootView {
    var iPadView: some View {
        #if targetEnvironment(macCatalyst)
        NavigationSplitView {
            sidebar
                .navigationTitle("Radix")
                .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
        #else
        GeometryReader { proxy in
            NavigationStack {
                HStack(spacing: 0) {
                    sidebar
                        .frame(width: iPadSidebarWidth(for: proxy.size.width))
                        .background(RadixTheme.background)
                        .overlay(alignment: .trailing) {
                            Divider()
                        }

                    detailPane
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
            }
        }
        #endif
    }

    private func iPadSidebarWidth(for availableWidth: CGFloat) -> CGFloat {
        min(420, max(320, availableWidth * 0.42))
    }

    @ViewBuilder
    var detailPane: some View {
        VStack(spacing: 12) {
            BreadcrumbStrip()
            if let error = store.loadingError {
                ContentUnavailableView("Failed to Load", systemImage: "exclamationmark.triangle", description: Text(error))
            } else {
                switch store.route {
                case .capture:
                    CaptureTab()
                case .search:
                    SearchHomeView(
                        onExportProfile: exportProfile,
                        onImportProfile: importProfile,
                        onLoadAddPhrases: loadAddPhrases,
                        onExportAddPhrases: exportAddPhrases,
                        onUseDefaultAddPhrases: useDefaultAddPhrases,
                        onRequirePro: presentPaywall(for:)
                    )
                case .lineage:
                    if store.previewCharacter == nil {
                        emptyStateCard(
                            systemImage: "tree",
                            title: "No Character",
                            message: "Choose a character from Search or Browse."
                        )
                    } else {
                        ComponentsExplorerShell(seedOverride: store.previewCharacter)
                    }
                case .favourites:
                    FavouritesTab(
                        onExportProfile: exportProfile,
                        onImportProfile: importProfile,
                        onRequirePro: presentPaywall(for:)
                    )
                case .aiLink:
                    aiLinkContent
                }
            }
        }
        .navigationTitle(detailPaneTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    var detailPaneTitle: String {
        switch store.route {
        case .capture:
            return "Scan"
        case .search:
            switch store.homeTab {
            case .smart:
                return "Search"
            case .filter:
                return store.selectedBrowseCollection.map { "Browse - \($0.name)" } ?? "Browse Dictionary"
            case .favourites:
                return "Study"
            case .dataEdit:
                return "My Data"
            }
        case .lineage:
            return "Character Breakdown"
        case .favourites:
            return "Study"
        case .aiLink:
            return "AI Link"
        }
    }

    @ViewBuilder
    var aiLinkContent: some View {
        if let current = store.previewCharacter,
           let item = store.item(for: current) {
            AILinkView(item: item)
        } else if store.selectedAICollection != nil {
            AILinkView(item: nil)
        } else {
            emptyStateCard(
                systemImage: RadixIcon.aiLink,
                title: "No Subject",
                message: "Choose a character, phrase, or page first."
            )
        }
    }
}
