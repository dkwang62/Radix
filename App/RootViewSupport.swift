import SwiftUI

struct SearchHomeView: View {
    @EnvironmentObject private var store: RadixStore
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onLoadAddPhrases: () -> Void
    let onExportAddPhrases: () -> Void
    let onUseDefaultAddPhrases: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void
    let onSaveSnapshot: () -> Void
    let onRestoreSnapshot: (LocalDataSnapshot?) -> Void
    let onRefreshSnapshots: () -> Void
    let localSnapshots: [LocalDataSnapshot]
    let isSavingSnapshot: Bool
    let isRestoringSnapshot: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            switch store.homeTab {
            case .smart:
                SmartSearchTab()
            case .filter:
                FilterGridTab()
            case .favourites:
                FavouritesTab(
                    onExportProfile: onExportProfile,
                    onImportProfile: onImportProfile,
                    onRequirePro: onRequirePro,
                    onOpenProtectRecover: {
                        store.goToDataEdit(preservingOrigin: true)
                    },
                    onCreateCheckpoint: onSaveSnapshot,
                    onReturnToCheckpoint: onRestoreSnapshot,
                    onRefreshCheckpoints: onRefreshSnapshots,
                    checkpoints: localSnapshots,
                    isCreatingCheckpoint: isSavingSnapshot,
                    isReturningToCheckpoint: isRestoringSnapshot
                )
            case .dataEdit:
                DataEditTab(
                    onLoadAddPhrases: onLoadAddPhrases,
                    onExportAddPhrases: onExportAddPhrases,
                    onUseDefaultAddPhrases: onUseDefaultAddPhrases,
                    onRequirePro: onRequirePro
                )
            }
        }
        .padding(.vertical, 8)
    }
}

extension RootView {
    var browseNavigationTitle: String {
        store.selectedBrowseCollection.map { "Browse \($0.name)" } ?? "Browse Dictionary"
    }

    var isBrowseDestinationActive: Bool {
        store.route == .search && store.homeTab == .filter
    }

    var browseTitleMenuPages: [CharacterCollection] {
        store.allCollections.sorted {
            let lhsDate = $0.lastViewedAt ?? $0.createdAt
            let rhsDate = $1.lastViewedAt ?? $1.createdAt
            if lhsDate != rhsDate { return lhsDate > rhsDate }
            return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
        }
    }

    var activeTitleGuideTopic: RadixNavigationGuideTopic? {
        if isBrowseDestinationActive { return .browse }
        switch store.route {
        case .search:
            switch store.homeTab {
            case .favourites:
                return .study
            case .dataEdit:
                return .myData
            case .smart, .filter:
                return nil
            }
        case .favourites:
            return .study
        case .aiLink:
            return .aiLink
        case .settings:
            return .settings
        case .capture, .lineage:
            return nil
        }
    }

    var showsTitleGuideMenu: Bool {
        activeTitleGuideTopic != nil
    }

    @ViewBuilder
    var titleGuideMenu: some View {
        if isBrowseDestinationActive {
            browseTitlePicker
        } else if let topic = activeTitleGuideTopic {
            navigationTitleMenu(for: topic)
        }
    }

    func navigationTitleMenu(for topic: RadixNavigationGuideTopic) -> some View {
        Menu {
            navigationHelpButton(for: topic)
        } label: {
            navigationTitleMenuLabel(topic.title)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .accessibilityLabel("\(topic.title) menu")
        .accessibilityValue(topic.title)
        .help("\(topic.title) menu")
    }

    var browseTitlePicker: some View {
        Menu {
            navigationHelpButton(for: .browse)

            Button {
                store.selectBrowseCollection(id: nil)
                store.shouldCloseBrowsePages = true
            } label: {
                Label("Dictionary", systemImage: store.selectedBrowseCollection == nil ? "checkmark" : "book")
            }

            if !browseTitleMenuPages.isEmpty {
                Section("Saved Pages") {
                    ForEach(browseTitleMenuPages) { collection in
                        Button {
                            store.selectBrowseCollection(id: collection.id)
                            store.shouldCloseBrowsePages = true
                        } label: {
                            let title = collection.name.isEmpty ? RadixCopy.savedPage : collection.name
                            let isSelected = store.selectedBrowseCollectionID == collection.id
                            Label(title, systemImage: isSelected ? "checkmark" : "photo.on.rectangle")
                        }
                    }
                }
            }

            Section {
                Button {
                    store.shouldOpenBrowsePages = true
                } label: {
                    Label("Browse Sources...", systemImage: RadixIcon.browse)
                }
            }
        } label: {
            navigationTitleMenuLabel(browseNavigationTitle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .id(store.selectedBrowseCollectionID?.uuidString ?? "dictionary")
        .accessibilityLabel("Browse menu")
        .accessibilityValue(browseNavigationTitle)
        .help("Browse menu")
    }

    func navigationHelpButton(for topic: RadixNavigationGuideTopic) -> some View {
        Button {
            offerNavigationGuide(topic, force: true)
        } label: {
            Label("Help", systemImage: RadixIcon.help)
        }
    }

    func navigationTitleMenuLabel(_ title: String) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(ResponsiveFont.headline.weight(.semibold))
                .lineLimit(1)
            Image(systemName: "chevron.down")
                .font(.system(size: 11, weight: .bold))
                .foregroundStyle(.secondary)
        }
        .foregroundStyle(.primary)
        .frame(maxWidth: 420)
    }

    /// Starts the same clean Search flow from every platform's primary navigation.
    func beginNewSearch() {
        store.clearInformationCardFocus()
        store.goToSearchRoot(restorePreview: false)
        DispatchQueue.main.async {
            store.query = ""
            store.clearSearch()
        }
    }

    func offerNavigationGuide(_ topic: RadixNavigationGuideTopic, force: Bool = false) {
        guard force || !RadixRootPreferences.hasSeenNavigationGuide(topic.id) else { return }
        navigationGuideTopic = topic
    }

    func handleNavigationGuideTap(
        _: RadixNavigationGuideTopic,
        isActive _: Bool,
        navigate: () -> Void
    ) {
        navigate()
    }

    func dismissNavigationGuide(_ topic: RadixNavigationGuideTopic) {
        RadixRootPreferences.setNavigationGuideSeen(topic.id)
        if navigationGuideTopic == topic {
            navigationGuideTopic = nil
        }
    }

}

struct NavigationGuidePopover: View {
    let topic: RadixNavigationGuideTopic
    let onDismiss: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                Label(topic.title, systemImage: topic.icon)
                    .font(ResponsiveFont.title3.weight(.bold))

                Text("Why it matters")
                    .font(ResponsiveFont.subheadline.weight(.bold))

                Text(topic.summary)
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Text("What you can do")
                    .font(ResponsiveFont.subheadline.weight(.bold))

                VStack(alignment: .leading, spacing: 12) {
                    ForEach(Array(topic.actions.enumerated()), id: \.offset) { _, action in
                        HStack(alignment: .top, spacing: 10) {
                            Image(systemName: action.icon)
                                .font(.system(size: 15, weight: .semibold))
                                .foregroundStyle(Color.accentColor)
                                .frame(width: 24, height: 24)
                                .background(Color.accentColor.opacity(0.1))
                                .clipShape(RoundedRectangle(cornerRadius: 6))

                            VStack(alignment: .leading, spacing: 2) {
                                Text(action.title)
                                    .font(ResponsiveFont.subheadline.weight(.semibold))
                                Text(action.detail)
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                    }
                }

                Label(topic.reminder, systemImage: "hand.tap")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button("Got it") {
                    onDismiss()
                }
                .buttonStyle(.borderedProminent)
                .frame(maxWidth: .infinity, alignment: .trailing)
            }
            .padding(16)
        }
        .frame(idealWidth: 360, maxWidth: 420)
        .frame(maxHeight: 560)
        .presentationCompactAdaptation(.popover)
        .accessibilityElement(children: .contain)
    }
}


func emptyStateCard(systemImage: String, title: String, message: String) -> some View {
    VStack(spacing: 8) {
        Image(systemName: systemImage)
            .font(.system(size: 44, weight: .light))
            .foregroundStyle(.secondary)
        Text(title)
            .font(ResponsiveFont.title3.bold())
        Text(message)
            .font(ResponsiveFont.body)
            .foregroundStyle(.secondary)
            .multilineTextAlignment(.center)
    }
    .padding()
    .frame(maxWidth: .infinity, alignment: .center)
    .background(RadixTheme.secondaryBackground)
    .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
    .padding()
}

struct PrimaryActionTile: View {
    let title: String
    let subtitle: String
    let systemImage: String
    let isPrimary: Bool

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .frame(width: 34, height: 34)
                .foregroundStyle(isPrimary ? Color.white : Color.accentColor)
                .background(isPrimary ? Color.white.opacity(0.18) : Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.callout.weight(.bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.78)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .lineLimit(1)
                    .minimumScaleFactor(0.72)
                    .opacity(isPrimary ? 0.86 : 0.72)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 10)
        .frame(maxWidth: .infinity, minHeight: RadixControlMetrics.prominentHeight, alignment: .leading)
        .foregroundStyle(isPrimary ? Color.white : Color.primary)
        .background(isPrimary ? Color.accentColor : RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
    }
}

@MainActor
func standardPhoneCharacterPreview(
    character: String,
    showAddToMemoryButton: Bool = true,
    onClear: @escaping () -> Void
) -> some View {
    CharacterPreviewHeader(
        character: character,
        showClearButton: true,
        showAddToMemoryButton: showAddToMemoryButton,
        isVertical: true,
        onClear: onClear
    )
    .padding(.bottom, 10)
}

struct CompactScriptToggle: View {
    let isTraditional: Bool
    var accessibilityLabel = "Chinese script"
    var minWidth: CGFloat = 34
    var height: CGFloat = 28
    let onToggle: () -> Void

    var body: some View {
        Button {
            onToggle()
        } label: {
            Text(isTraditional ? "繁" : "简")
                .font(ResponsiveFont.caption.weight(.semibold))
                .frame(minWidth: minWidth, minHeight: height)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(accessibilityLabel)
        .accessibilityValue(isTraditional ? "Traditional" : "Simplified")
        .accessibilityHint("Toggles between simplified and traditional Chinese")
        .help(isTraditional ? "Traditional Chinese" : "Simplified Chinese")
    }
}

struct CompactScriptFilterControl: View {
    let selection: ScriptFilter
    let onChange: (ScriptFilter) -> Void

    private var label: String {
        switch selection {
        case .any: return "简繁"
        case .simplified: return "简"
        case .traditional: return "繁"
        }
    }

    var body: some View {
        Menu {
            scriptOption("Simplified and Traditional", value: .any)
            scriptOption("Simplified", value: .simplified)
            scriptOption("Traditional", value: .traditional)
        } label: {
            Text(label)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .frame(minWidth: selection == .any ? 44 : 34, minHeight: RadixControlMetrics.compactHeight)
                .padding(.horizontal, selection == .any ? 2 : 0)
                .background(Color.accentColor)
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Character set")
        .accessibilityValue(selection.rawValue)
        .accessibilityHint("Choose simplified, traditional, or both")
    }

    @ViewBuilder
    private func scriptOption(_ title: String, value: ScriptFilter) -> some View {
        Button {
            onChange(value)
        } label: {
            if selection == value {
                Label(title, systemImage: "checkmark")
            } else {
                Text(title)
            }
        }
    }
}

struct RadixWelcomeView: View {
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Radix")
                            .font(ResponsiveFont.title.bold())
                        Text("Scan, understand, and save Chinese characters.")
                            .font(ResponsiveFont.title3)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    VStack(alignment: .leading, spacing: 12) {
                        welcomeStep(
                            icon: RadixIcon.scan,
                            title: "Capture and find Chinese",
                            text: "Take a photo or use Search whenever you need to bring material into Radix or find something directly."
                        )

                        Text("Four main areas")
                            .font(ResponsiveFont.subheadline.weight(.bold))
                            .padding(.top, 4)

                        welcomeStep(
                            icon: RadixIcon.browse,
                            title: RadixCopy.browse,
                            text: RadixCopy.browsePurpose
                        )
                        welcomeStep(
                            icon: RadixIcon.study,
                            title: RadixCopy.study,
                            text: RadixCopy.studyPurpose
                        )
                        welcomeStep(
                            icon: RadixIcon.aiLink,
                            title: "AI",
                            text: RadixCopy.aiPurpose
                        )
                        welcomeStep(
                            icon: RadixIcon.myData,
                            title: RadixCopy.myData,
                            text: RadixCopy.myDataPurpose
                        )
                    }

                    Button(action: onDone) {
                        Text("Start Using Radix")
                            .font(ResponsiveFont.body.weight(.semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(24)
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Skip", action: onDone)
                }
            }
        }
    }

    private func welcomeStep(icon: String, title: String, text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(ResponsiveFont.title3)
                .foregroundStyle(Color.accentColor)
                .frame(width: 40, height: 40)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                Text(text)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.7))
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
    }
}
