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
            crossTabReturnBar
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
                        onRequirePro: presentPaywall(for:),
                        onSaveSnapshot: quickSaveMemory,
                        onRestoreSnapshot: quickRestoreMemory(from:),
                        onRefreshSnapshots: refreshQuickLocalSnapshots,
                        localSnapshots: quickLocalSnapshots,
                        isSavingSnapshot: isQuickSavingMemory,
                        isRestoringSnapshot: isQuickRestoringMemory
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
                        onRequirePro: presentPaywall(for:),
                        onOpenProtectRecover: {
                            store.goToDataEdit(preservingOrigin: true)
                        },
                        onCreateCheckpoint: quickSaveMemory,
                        onReturnToCheckpoint: quickRestoreMemory(from:),
                        onRefreshCheckpoints: refreshQuickLocalSnapshots,
                        checkpoints: quickLocalSnapshots,
                        isCreatingCheckpoint: isQuickSavingMemory,
                        isReturningToCheckpoint: isQuickRestoringMemory
                    )
                case .aiLink:
                    aiLinkContent
                case .settings:
                    SettingsView(showsCloseButton: false) {
                        hasSeenWelcome = false
                    }
                    .environmentObject(store)
                }
            }
        }
        .navigationTitle(detailPaneTitle)
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if showsTitleGuideMenu {
                ToolbarItem(placement: .principal) {
                    titleGuideMenu
                }
            }
        }
    }

    @ViewBuilder
    var crossTabReturnBar: some View {
        if store.showsCrossTabReturn {
            HStack {
                Button {
                    store.returnFromRoots()
                } label: {
                    Label(store.rootsReturnButtonTitle, systemImage: "arrow.uturn.backward")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Spacer()
            }
            .padding(.horizontal)
            .padding(.top, 6)
        }
    }

    var detailPaneTitle: String {
        switch store.route {
        case .capture:
            return "Camera"
        case .search:
            switch store.homeTab {
            case .smart:
                return "Search"
            case .filter:
                return browseNavigationTitle
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
        case .settings:
            return "Settings"
        }
    }

    @ViewBuilder
    var aiLinkContent: some View {
        if let current = store.previewCharacter,
           let item = store.item(for: current) {
            AILinkView(item: item)
        } else if store.activeSidebarPhrasePreview != nil || store.selectedAICollection != nil {
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
