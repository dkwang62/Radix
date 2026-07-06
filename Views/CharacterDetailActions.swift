import SwiftUI

extension CharacterDetailView {
    func regularActionRow(proxy: ScrollViewProxy) -> some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 8) {
                detailActionButtons(proxy: proxy)
            }
            VStack(alignment: .leading, spacing: 8) {
                detailActionButtons(proxy: proxy)
            }
        }
    }

    private func detailActionButtons(proxy: ScrollViewProxy) -> some View {
        Group {
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
                Text(showPhraseTable ? "Hide Phrases" : "Phrases")
                Spacer()
                Text("\(store.activePhraseLengthFilterLabel)-char")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .characterDetailActionSurface(font: ResponsiveFont.subheadline.weight(.semibold))
        }
        .buttonStyle(.plain)
    }

    var editCharacterButton: some View {
        Button {
            store.openQuickCharacterEditor(item.character)
        } label: {
            Label("Notes", systemImage: "square.and.pencil")
                .characterDetailActionSurface()
        }
        .buttonStyle(.plain)
    }

    var rootsButton: some View {
        Button {
            store.goToRoots(character: item.character)
        } label: {
            Label("Breakdown", systemImage: "tree")
                .characterDetailActionSurface()
        }
        .buttonStyle(.plain)
    }
}

private extension View {
    func characterDetailActionSurface(
        font: Font = ResponsiveFont.caption.weight(.semibold)
    ) -> some View {
        self
            .font(font)
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .radixSurface(RadixTheme.secondaryBackground)
            .frame(minHeight: 42)
    }
}
