import SwiftUI

struct CharacterInfoCardActions: View {
    @EnvironmentObject private var store: RadixStore

    let character: String
    let showClearButton: Bool
    let isPhone: Bool
    let onShowPhrases: (() -> Void)?
    let onShowExamples: (() -> Void)?
    let onClear: (() -> Void)?

    var body: some View {
        HStack(spacing: 8) {
            notesButton
            phrasesButton
            if hasExamples {
                examplesButton
            }
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
            InfoCardActionPill(title: "Notes", systemImage: "square.and.pencil")
        }
        .buttonStyle(.plain)
    }

    private var phrasesButton: some View {
        Button {
            store.refreshPhrases(for: character)
            onShowPhrases?()
        } label: {
            InfoCardActionPill(title: "Phrases", textIcon: "词")
        }
        .buttonStyle(.plain)
    }

    private var examplesButton: some View {
        Button {
            onShowExamples?()
        } label: {
            InfoCardActionPill(title: "Examples", systemImage: RadixGlossaryIcon.systemImage(for: "Sentence"))
        }
        .buttonStyle(.plain)
        .help("Show sentence examples")
    }

    private var hasExamples: Bool {
        !SentenceExampleDisplayRules.examples(containingCharacter: character, limit: 1).isEmpty
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

struct InfoCardActionPill: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let title: String
    var systemImage: String?
    var textIcon: String?
    var verticalPadding: CGFloat = 7

    var body: some View {
        HStack(spacing: 5) {
            if let systemImage {
                Image(systemName: systemImage)
            } else if let textIcon {
                Text(textIcon)
                    .font(cardActionFont)
            }

            Text(title)
        }
        .font(cardActionFont)
        .foregroundStyle(RadixAccent.primary)
        .lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)
        .radixPill(
            horizontal: 10,
            vertical: verticalPadding,
            background: RadixTheme.secondaryBackground,
            border: RadixTheme.separator,
            borderWidth: 0.5
        )
    }

    private var cardActionFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.caption2.weight(.semibold)
        #else
        return ResponsiveFont.caption.weight(.semibold)
        #endif
    }
}
