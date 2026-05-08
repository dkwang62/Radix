import SwiftUI

struct CharacterInfoCardActions: View {
    @EnvironmentObject private var store: RadixStore

    let character: String
    let showClearButton: Bool
    let isPhone: Bool
    let onShowPhrases: (() -> Void)?
    let onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            notesButton
            phrasesButton
            if !isPhone, showClearButton, onClear != nil {
                clearPreviewButton
            }
            Spacer(minLength: 0)
        }
    }

    private var notesButton: some View {
        Button {
            store.openQuickCharacterEditor(character)
        } label: {
            actionPill("Notes", systemImage: "square.and.pencil")
        }
        .buttonStyle(.plain)
    }

    private var phrasesButton: some View {
        Button {
            store.refreshPhrases(for: character)
            onShowPhrases?()
        } label: {
            actionPill("Phrases", systemImage: "character.bubble")
        }
        .buttonStyle(.plain)
    }

    private var clearPreviewButton: some View {
        Button {
            onClear?()
        } label: {
            Text("Clear Preview")
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
    }

    private func actionPill(_ title: String, systemImage: String) -> some View {
        Label(title, systemImage: systemImage)
            .font(cardActionFont)
            .foregroundStyle(Color.accentColor)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
    }

    private var cardActionFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.caption2.weight(.semibold)
        #else
        return ResponsiveFont.caption.weight(.semibold)
        #endif
    }

    private var cardActionControlSize: ControlSize {
        #if targetEnvironment(macCatalyst)
        return .small
        #else
        return .regular
        #endif
    }
}
