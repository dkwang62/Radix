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
                    onSaveSnapshot: onSaveSnapshot,
                    onRestoreSnapshot: onRestoreSnapshot,
                    onRefreshSnapshots: onRefreshSnapshots,
                    localSnapshots: localSnapshots,
                    isSavingSnapshot: isSavingSnapshot,
                    isRestoringSnapshot: isRestoringSnapshot
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

    /// Starts the same clean Search flow from every platform's primary navigation.
    func beginNewSearch() {
        store.showiPhoneDetail = false
        store.goToSearchRoot()
        DispatchQueue.main.async {
            store.query = ""
            store.clearSearch()
        }
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
                    .font(ResponsiveFont.subheadline.weight(.bold))
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

                    VStack(spacing: 12) {
                        welcomeStep(
                            icon: RadixIcon.scan,
                            title: "Scan real text",
                            text: "Turn a photo, file, or pasted text into a saved page you can browse."
                        )
                        welcomeStep(
                            icon: RadixIcon.browse,
                            title: "Browse the dictionary",
                            text: "Explore characters, saved pages, parts, variants, stroke order, and phrases."
                        )
                        welcomeStep(
                            icon: RadixIcon.search,
                            title: "Search naturally",
                            text: "Find Chinese by character, pinyin, English meaning, stroke input, or phrase."
                        )
                        welcomeStep(
                            icon: RadixIcon.study,
                            title: "Keep what matters",
                            text: "Save useful characters, phrases, notes, and pages in Study."
                        )
                        welcomeStep(
                            icon: RadixIcon.myData,
                            title: "Move My Data",
                            text: "What you add on iPhone can travel to iPad and Mac with Radix Plus."
                        )
                        welcomeStep(
                            icon: RadixIcon.aiLink,
                            title: "Use AI Link",
                            text: "Send repeatable AI actions for phrase extraction, translation, and interpretation."
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
