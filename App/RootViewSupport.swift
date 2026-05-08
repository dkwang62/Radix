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
    .background(Color(.secondarySystemBackground))
    .clipShape(RoundedRectangle(cornerRadius: 16))
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
                .background(isActive ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isActive ? .white : .primary)
                .clipShape(RoundedRectangle(cornerRadius: 9))
        }
        .buttonStyle(.plain)
    }
}
