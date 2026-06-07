import SwiftUI

struct SearchHomeView: View {
    @EnvironmentObject private var store: RadixStore
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onLoadAddPhrases: () -> Void
    let onExportAddPhrases: () -> Void
    let onUseDefaultAddPhrases: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

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
                    onRequirePro: onRequirePro
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
    .clipShape(RoundedRectangle(cornerRadius: 8))
    .padding()
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

struct CompactScriptFilterControl: View {
    let selection: ScriptFilter
    let onChange: (ScriptFilter) -> Void

    private var simplifiedActive: Bool {
        selection == .any || selection == .simplified
    }

    private var traditionalActive: Bool {
        selection == .any || selection == .traditional
    }

    var body: some View {
        HStack(spacing: 4) {
            scriptButton("简", isActive: simplifiedActive) {
                switch selection {
                case .any:
                    onChange(.simplified)
                case .simplified:
                    onChange(.any)
                case .traditional:
                    onChange(.any)
                }
            }

            scriptButton("繁", isActive: traditionalActive) {
                switch selection {
                case .any:
                    onChange(.traditional)
                case .simplified:
                    onChange(.any)
                case .traditional:
                    onChange(.any)
                }
            }
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Character set")
        .accessibilityValue(selection.rawValue)
    }

    private func scriptButton(_ title: String, isActive: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .frame(width: 34, height: 34)
                .background(isActive ? Color.accentColor : RadixTheme.secondaryBackground)
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
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
                .clipShape(RoundedRectangle(cornerRadius: 8))

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
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
