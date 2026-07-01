import SwiftUI

extension RootView {
    var sidebar: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                sidebarBrandHeader

                sidebarGlobalActionRow
                sidebarMainNavigation

                if sidebarShowsInfoCard {
                    sidebarPreview
                } else {
                    sidebarCheckpointsSection
                }
            }
            .padding(8)
        }
    }

    var sidebarShowsInfoCard: Bool {
        store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil
    }

    var sidebarBrandHeader: some View {
        VStack(alignment: .leading, spacing: 6) {
            if !hasUsedSidebarNavigation {
                Text("Lifelong Chinese Companion")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                Text("Scan, save, study, and carry your Chinese across devices.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(.horizontal, 4)
        .padding(.top, 4)
    }

    var sidebarGlobalActionRow: some View {
        HStack(spacing: 8) {
            Button {
                hasUsedSidebarNavigation = true
                beginNewSearch()
            } label: {
                PrimaryActionTile(
                    title: "Search",
                    subtitle: "Anything",
                    systemImage: RadixIcon.search,
                    isPrimary: false
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Search in Radix")

            Button {
                hasUsedSidebarNavigation = true
                store.clearInformationCardFocus()
                store.startBrowseCameraPage()
            } label: {
                PrimaryActionTile(
                    title: "Camera",
                    subtitle: "Capture text",
                    systemImage: "camera.fill",
                    isPrimary: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Camera")
        }
    }

    var sidebarMainNavigation: some View {
        HStack(spacing: 6) {
            sidebarTabButton(.browse)
            sidebarTabButton(.study)
            sidebarTabButton(.aiLink)
            sidebarTabButton(.myData)
            sidebarSettingsTabButton
        }
    }

    func sidebarTabButton(_ item: RadixNavigationItem) -> some View {
        let id = item.rawValue
        let guideTopic = item.guideTopic ?? .browse
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = {
            if store.route == .favourites { return id == 3 }
            if store.route == .aiLink { return id == 4 }
            if store.route == .lineage { return false }
            if store.route == .capture { return false }
            if store.route == .settings { return false }
            switch store.homeTab {
            case .smart: return false
            case .filter: return id == 2
            case .favourites: return id == 3
            case .dataEdit: return id == 5
            }
        }()

        return Button {
            handleNavigationGuideTap(guideTopic, isActive: isActive) {
                store.clearCrossTabOrigin()
                store.clearInformationCardFocus()
                switch id {
                case 2:
                    hasUsedSidebarNavigation = true
                    store.goToBrowse()
                case 3:
                    hasUsedSidebarNavigation = true
                    store.goToFavourites()
                case 4:
                    hasUsedSidebarNavigation = true
                    store.enterAILink()
                case 5:
                    hasUsedSidebarNavigation = true
                    store.goToDataEdit()
                default:
                    break
                }
            }
        } label: {
            VStack(spacing: showsTitle ? 2 : 0) {
                Image(systemName: item.icon)
                    .font(.system(size: isActive ? 17 : 16, weight: .semibold))
                if showsTitle {
                    Text(item.compactTitle)
                        .font(ResponsiveFont.tinySystem(size: 10, weight: isActive ? .bold : .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.58)
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor : RadixTheme.secondaryBackground.opacity(0.65))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(item.title)
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("\(item.subtitle) Select this destination again to show its guide.")
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                } else {
                    EmptyView()
                }
            }
        )
        .help(guideTopic.summary)
    }

    var sidebarSettingsTabButton: some View {
        let showsTitle = store.sidebarNavigationStyle == .descriptive
        let isActive = store.route == .settings

        return Button {
            handleNavigationGuideTap(.settings, isActive: isActive) {
                store.clearCrossTabOrigin()
                store.clearInformationCardFocus()
                hasUsedSidebarNavigation = true
                store.goToSettings()
            }
        } label: {
            VStack(spacing: showsTitle ? 2 : 0) {
                Image(systemName: RadixIcon.settings)
                    .font(.system(size: 16, weight: .semibold))
                if showsTitle {
                    Text("Settings")
                        .font(ResponsiveFont.tinySystem(size: 10, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.52)
                }
            }
            .foregroundStyle(isActive ? Color.white : Color.secondary)
            .frame(maxWidth: .infinity)
            .frame(height: showsTitle ? 48 : 42)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isActive ? Color.accentColor : RadixTheme.secondaryBackground.opacity(0.65))
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Settings")
        .accessibilityValue(isActive ? "Selected" : "")
        .accessibilityHint("\(RadixNavigationGuideTopic.settings.summary) Select Settings again to show its guide.")
        .overlay(
            Group {
                if isActive {
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color.accentColor.opacity(0.35), lineWidth: 1)
                } else {
                    EmptyView()
                }
            }
        )
        .help(RadixNavigationGuideTopic.settings.summary)
    }

    var sidebarCheckpointsSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .firstTextBaseline) {
                Label("Checkpoints", systemImage: "clock.arrow.circlepath")
                    .font(ResponsiveFont.subheadline.weight(.bold))
                Spacer()
                if quickLocalSnapshots.count > 3 {
                    Text("\(quickLocalSnapshots.count)")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                }
            }

            Button {
                store.clearInformationCardFocus()
                quickSaveMemory()
            } label: {
                sidebarCheckpointActionContent(
                    title: isQuickSavingMemory ? "Creating..." : RadixCopy.createCheckpoint,
                    subtitle: "Save this moment",
                    systemImage: "clock.badge.checkmark",
                    isLocked: entitlement.requiresPro(.datedCopies)
                )
            }
            .buttonStyle(.plain)
            .disabled(isQuickSavingMemory || isQuickRestoringMemory)

            sidebarCheckpointRows
        }
        .padding(8)
        .background(RadixTheme.secondaryBackground.opacity(0.58))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadixTheme.separator, lineWidth: 0.5)
        )
    }

    @ViewBuilder
    var sidebarCheckpointRows: some View {
        if quickLocalSnapshots.isEmpty {
            Text("No checkpoints created yet.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(8)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            VStack(spacing: 6) {
                ForEach(Array(quickLocalSnapshots.prefix(3))) { checkpoint in
                    Button {
                        store.clearInformationCardFocus()
                        pendingSidebarCheckpointReturn = checkpoint
                    } label: {
                        sidebarCheckpointRow(checkpoint)
                    }
                    .buttonStyle(.plain)
                    .disabled(isQuickSavingMemory || isQuickRestoringMemory)
                }
            }
        }
    }

    func sidebarCheckpointActionContent(
        title: String,
        subtitle: String,
        systemImage: String,
        isLocked: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLocked ? "lock.fill" : systemImage)
                .font(.system(size: 14, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
        .background(Color.accentColor.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func sidebarCheckpointRow(_ checkpoint: LocalDataSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(checkpoint.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                Text(checkpoint.relativeSavedText)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .layoutPriority(1)

            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var sidebarPreview: some View {
        VStack(alignment: .leading, spacing: 8) {
            Group {
                if let phrase = store.activeSidebarPhrasePreview {
                    PhraseInfoCard(
                        phrase: phrase,
                        phraseLookupOverride: store.sidebarPhraseLookupOverride,
                        onDone: {
                            store.dismissSidebarPhrasePreview()
                        }
                    )
                    .environmentObject(store)
                } else if let current = store.previewCharacter {
                    CharacterPreviewHeader(
                        character: current,
                        showClearButton: false,
                        showAddToMemoryButton: !(store.route == .search && store.homeTab == .favourites),
                        isVertical: true
                    )
                } else {
                    EmptyView()
                }
            }
            .padding(8)
            .background(RadixTheme.secondaryBackground.opacity(0.7))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator, lineWidth: 0.5)
            )
        }
    }

}
