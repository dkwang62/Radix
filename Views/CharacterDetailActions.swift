import SwiftUI

extension CharacterDetailView {
    func regularActionRow(proxy: ScrollViewProxy) -> some View {
        HStack(spacing: 8) {
            editCharacterButton
            phraseTableButton {
                withAnimation(.easeInOut(duration: 0.2)) {
                    showPhraseTable.toggle()
                }
                if showPhraseTable {
                    store.refreshPhrases()
                    DispatchQueue.main.async {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            proxy.scrollTo("phraseTableSection", anchor: .top)
                        }
                    }
                }
            }
            rootsButton
        }
    }

    func phraseTableButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: showPhraseTable ? "text.justify" : "text.justify.left")
                Text(showPhraseTable ? "Hide Phrase Table" : "Show Phrase Table")
                Spacer()
                Text("\(store.phraseLength)-char")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(ResponsiveFont.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    var editCharacterButton: some View {
        Button {
            store.openQuickCharacterEditor(item.character)
        } label: {
            Label("Notes", systemImage: "square.and.pencil")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    var rootsButton: some View {
        Button {
            store.goToRoots(character: item.character)
        } label: {
            Label("Components", systemImage: "tree")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}
