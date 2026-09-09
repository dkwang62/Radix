import SwiftUI

extension RootView {
    var iPadView: some View {
        #if targetEnvironment(macCatalyst)
        NavigationSplitView {
            sidebar
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
        let content = VStack(spacing: 12) {
            #if targetEnvironment(macCatalyst)
            catalystDetailTitleBar
            #endif
            crossTabReturnBar
            BreadcrumbStrip()
            if let error = store.loadingError, !isStartupRecoveryDestination {
                startupRecoveryView(error: error)
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

        #if targetEnvironment(macCatalyst)
        content
        #else
        content
            .navigationTitle(detailPaneTitle)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .principal) {
                    titleGuideMenu
                }
            }
        #endif
    }

    var isStartupRecoveryDestination: Bool {
        store.route == .settings || (store.route == .search && store.homeTab == .dataEdit)
    }

    func startupRecoveryView(error: String) -> some View {
        VStack(spacing: 16) {
            ContentUnavailableView(
                "Failed to Load",
                systemImage: "exclamationmark.triangle",
                description: Text(error)
            )

            HStack(spacing: 12) {
                Button("Retry") {
                    Task { await store.initialize() }
                }
                .buttonStyle(.borderedProminent)

                Button("My Data") {
                    store.goToDataEdit()
                }
                .buttonStyle(.bordered)

                Button("Settings") {
                    store.goToSettings()
                }
                .buttonStyle(.bordered)
            }
        }
        .padding()
    }

    @ViewBuilder
    var catalystDetailTitleBar: some View {
        HStack {
            Spacer(minLength: 0)

            titleGuideMenu

            Spacer(minLength: 0)
        }
        .padding(.horizontal)
        .padding(.top, 8)
        .accessibilityAddTraits(.isHeader)
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
                return "Study - \(store.activeStudySectionTitle)"
            case .dataEdit:
                return "\(RadixCopy.myData) - \(store.activeDataEditSection.rawValue)"
            }
        case .lineage:
            return "Character Breakdown"
        case .favourites:
            return "Study - \(store.activeStudySectionTitle)"
        case .aiLink:
            if store.rootsReturnContext == nil {
                return "AI - Templates"
            }
            return selectedTitleMenuPromptTaskTitle.map { "AI - \($0)" } ?? "AI"
        case .settings:
            return "Settings"
        }
    }

    @ViewBuilder
    var aiLinkContent: some View {
        let item = store.previewCharacter.flatMap { store.item(for: $0) }
        AILinkView(item: item)
    }
}
