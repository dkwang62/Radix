import SwiftUI

extension RootView {
    var iPadView: some View {
        NavigationSplitView {
            sidebar
                .navigationTitle("Radix")
                .navigationSplitViewColumnWidth(min: 320, ideal: 360, max: 420)
        } detail: {
            detailPane
        }
        .navigationSplitViewStyle(.balanced)
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
                systemImage: "sparkles",
                title: "No Subject",
                message: "Choose a character, phrase, or page first."
            )
        }
    }
}
