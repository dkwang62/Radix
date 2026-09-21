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
        store.selectedBrowseCollection.map { "Browse - \($0.name)" } ?? "Browse - Dictionary"
    }

    var isBrowseDestinationActive: Bool {
        store.route == .search && store.homeTab == .filter
    }

    var isStudyDestinationActive: Bool {
        let isStudyRoute = store.route == .favourites || (store.route == .search && store.homeTab == .favourites)
        return isStudyRoute && !isPagesDestinationActive
    }

    var isPagesDestinationActive: Bool {
        let isStudyRoute = store.route == .favourites || (store.route == .search && store.homeTab == .favourites)
        return isStudyRoute && store.activeStudySectionTitle == StudyNavigationTarget.savedPages.title
    }

    var isCheckpointsDestinationActive: Bool {
        isStudyDestinationActive && store.activeStudySectionTitle == "Checkpoints"
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

    @ViewBuilder
    var titleGuideMenu: some View {
        rootTitleNavigationMenu
    }

    var rootTitleNavigationMenu: some View {
        Menu {
            createPageTitleMenuSection
            browseTitleMenuSection
            studyTitleMenuSection
            aiTitleMenuButton
            myDataTitleMenuSection
            appTitleMenuSection
        } label: {
            navigationTitleMenuLabel(detailPaneTitle)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .id(titleNavigationIdentity)
        .accessibilityLabel("Radix navigation menu")
        .accessibilityValue(detailPaneTitle)
        .help("Radix navigation menu")
    }

    var titleNavigationIdentity: String {
        [
            store.route.rawValue,
            store.homeTab.rawValue,
            store.selectedBrowseCollectionID?.uuidString ?? "dictionary",
            store.activeStudySectionTitle,
            store.activeDataEditSection.rawValue,
            selectedTitleMenuPromptTaskID ?? "no-task"
        ].joined(separator: "|")
    }

    func performTitleMenuSelection(_ action: () -> Void) {
        store.overrideIncompleteActionsForTitleSelection()
        action()
    }

    @ViewBuilder
    var createPageTitleMenuSection: some View {
        Section("Create Page") {
            titleMenuButton("From Text", systemImage: "doc.text") {
                store.startCaptureTextPage()
            }
            titleMenuButton("From Photos", systemImage: "photo.on.rectangle") {
                store.startCaptureAlbumPage()
            }
            titleMenuButton("From Files", systemImage: "folder") {
                store.startCaptureFilePage()
            }
            titleMenuButton("From Clipboard", systemImage: "doc.on.clipboard") {
                store.startCaptureClipboardImagePage()
            }
            titleMenuButton("From Transcripts", systemImage: "text.quote") {
                store.goToTranscriptAI()
            }
        }
    }

    @ViewBuilder
    var browseTitleMenuSection: some View {
        Section("Browse") {
            Button {
                performTitleMenuSelection {
                    store.goToBrowse()
                    store.selectBrowseCollection(id: nil)
                    store.shouldCloseBrowseSource = true
                }
            } label: {
                Label(
                    "Dictionary",
                    systemImage: isBrowseDestinationActive && store.selectedBrowseCollection == nil ? "checkmark" : "book"
                )
            }

            Button {
                performTitleMenuSelection {
                    store.goToBrowse()
                }
            } label: {
                Label(
                    "Pages",
                    systemImage: isBrowseDestinationActive && store.selectedBrowseCollection != nil
                        ? "checkmark"
                        : RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage)
                )
            }
        }
    }

    @ViewBuilder
    var studyTitleMenuSection: some View {
        Section("Study") {
            ForEach(studyTitleMenuTargets) { target in
                Button {
                    performTitleMenuSelection {
                        store.activeStudySectionTitle = target.title
                        store.requestedStudyNavigationTarget = target
                        store.goToFavourites()
                    }
                } label: {
                    Label(
                        target.menuTitle,
                        systemImage: (isStudyDestinationActive || isPagesDestinationActive)
                            && target.title == store.activeStudySectionTitle
                            ? "checkmark"
                            : studyTitleMenuSystemImage(for: target)
                    )
                }
            }
        }
    }

    var studyTitleMenuTargets: [StudyNavigationTarget] {
        StudyNavigationTarget.allCases
    }

    var aiTitleMenuButton: some View {
        Button {
            performTitleMenuSelection {
                store.enterAILink()
            }
        } label: {
            Label("AI", systemImage: store.route == .aiLink ? "checkmark" : RadixIcon.aiLink)
        }
    }

    var selectedTitleMenuPromptTaskID: String? {
        let normalizedTasks = store.promptConfig.normalized().tasks
        if let selected = store.selectedPromptTaskID,
           normalizedTasks.contains(where: { $0.id == selected }) {
            return selected
        }
        if let saved = store.promptSelectedTaskIDs.first,
           normalizedTasks.contains(where: { $0.id == saved }) {
            return saved
        }
        return normalizedTasks.first?.id
    }

    var selectedTitleMenuPromptTaskTitle: String? {
        guard let selectedTitleMenuPromptTaskID else { return nil }
        return store.promptConfig.normalized().tasks.first { $0.id == selectedTitleMenuPromptTaskID }?.title
    }

    @ViewBuilder
    var myDataTitleMenuSection: some View {
        Section(RadixCopy.myData) {
            ForEach(DataEditSection.allCases) { section in
                Button {
                    performTitleMenuSelection {
                        store.goToDataEdit()
                        store.activeDataEditSection = section
                    }
                } label: {
                    Label(
                        myDataTitleMenuTitle(for: section),
                        systemImage: store.route == .search
                            && store.homeTab == .dataEdit
                            && section == store.activeDataEditSection
                            ? "checkmark"
                            : myDataTitleMenuSystemImage(for: section)
                    )
                }
            }
        }
    }

    @ViewBuilder
    var appTitleMenuSection: some View {
        Section("App") {
            Button {
                performTitleMenuSelection {
                    store.goToSettings()
                }
            } label: {
                Label("Settings", systemImage: store.route == .settings ? "checkmark" : RadixIcon.settings)
            }

            navigationHelpButton(for: activeTitleGuideTopic ?? .settings)
        }
    }

    private func titleMenuButton(
        _ title: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            performTitleMenuSelection(action)
        } label: {
            Label(title, systemImage: systemImage)
        }
    }

    func myDataTitleMenuSystemImage(for section: DataEditSection) -> String {
        switch section {
        case .myBackup:
            return "externaldrive"
        case .advanced:
            return "hammer"
        }
    }

    func myDataTitleMenuTitle(for section: DataEditSection) -> String {
        switch section {
        case .myBackup:
            return "Backups"
        case .advanced:
            return "Advanced"
        }
    }

    func studyTitleMenuSystemImage(for target: StudyNavigationTarget) -> String {
        switch target {
        case .recent:
            return RadixGlossaryIcon.systemImage(for: RadixTerm.recent)
        case .favorites:
            return RadixIcon.saved
        case .savedPages:
            return RadixGlossaryIcon.systemImage(for: RadixTerm.savedPage)
        case .addedPhrases:
            return "text.quote"
        case .conversationPractice:
            return "bubble.left.and.bubble.right"
        case .sentences:
            return RadixGlossaryIcon.systemImage(for: "Sentence")
        case .checkpoints:
            return "clock.arrow.circlepath"
        }
    }

    func navigationHelpButton(for topic: RadixNavigationGuideTopic) -> some View {
        Button {
            offerNavigationGuide(topic, force: true)
        } label: {
            RadixHelpLabel()
        }
    }

    func navigationTitleMenuLabel(_ title: String) -> some View {
        RadixCompactChevronLabel(
            title: title,
            font: ResponsiveFont.headline.weight(.semibold),
            chevronFont: .system(size: 11, weight: .bold),
            chevronForegroundStyle: .secondary,
            spacing: 4
        )
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
                                .foregroundStyle(RadixAccent.primary)
                                .radixIconButtonSurface(
                                    size: 24,
                                    background: RadixAccent.primary.opacity(0.1),
                                    radius: 6
                                )

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


@MainActor
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
    .radixSurface(RadixTheme.secondaryBackground)
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
                .foregroundStyle(isPrimary ? Color.white : RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 34,
                    background: isPrimary ? Color.white.opacity(0.18) : RadixAccent.primary.opacity(0.12)
                )

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
        .radixSurface(isPrimary ? RadixAccent.primary : RadixTheme.secondaryBackground)
    }
}

struct GlobalSearchCameraActionRow: View {
    var onSearch: () -> Void
    var onCamera: () -> Void

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSearch) {
                PrimaryActionTile(
                    title: "Search",
                    subtitle: "Anything",
                    systemImage: RadixIcon.search,
                    isPrimary: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search in Radix")

            Button(action: onCamera) {
                PrimaryActionTile(
                    title: "Camera",
                    subtitle: "Capture text",
                    systemImage: RadixIcon.scan,
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera")
        }
    }
}

extension RootView {
    func openSearchFromGlobalAction(markSidebarUsed: Bool = false) {
        if markSidebarUsed {
            hasUsedSidebarNavigation = true
        }
        beginNewSearch()
    }

    func openCameraFromGlobalAction(markSidebarUsed: Bool = false) {
        if markSidebarUsed {
            hasUsedSidebarNavigation = true
        }
        store.clearInformationCardFocus()
        store.startBrowseCameraPage()
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
                .font(ResponsiveFont.scalableCaption.weight(.semibold))
                .frame(minWidth: minWidth, minHeight: height)
                .foregroundStyle(.white)
                .radixSurface(RadixAccent.primary)
        }
        .buttonStyle(.plain)
        .radixMinimumTapTarget()
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
                .foregroundStyle(.white)
                .radixSurface(RadixAccent.primary, radius: 9)
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
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 40,
                    background: RadixAccent.primary.opacity(0.12)
                )

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
        .radixSurface(RadixTheme.secondaryBackground.opacity(0.7))
    }
}
