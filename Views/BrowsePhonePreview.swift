import SwiftUI

struct BrowsePhonePreview: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem?
    let character: String?
    let onReturn: () -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                onReturn()
            } label: {
                Label("Browse", systemImage: "square.grid.2x2")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            if let phrase {
                PhraseInfoCard(
                    phrase: phrase,
                    onSelectCharacter: { character in
                        store.previewPhraseCardCharacter(character, in: phrase, announce: false)
                    },
                    onDone: onReturn
                )
                    .environmentObject(store)
            } else if let character {
                standardPhoneCharacterPreview(
                    character: character,
                    showAddToMemoryButton: false,
                    onClear: onReturn
                )
            }
        }
    }
}
