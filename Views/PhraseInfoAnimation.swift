import SwiftUI

extension PhraseInfoCard {
    @ViewBuilder
    var animationGrid: some View {
        let characters = Array(phraseCharacters.prefix(12))
        LazyVGrid(columns: phraseGridColumns, spacing: 10) {
            ForEach(Array(characters.enumerated()), id: \.offset) { _, character in
                phraseCharacterTile(character)
            }
        }
    }

    var phraseGridColumns: [GridItem] {
        [
            GridItem(.flexible(minimum: 120), spacing: 10),
            GridItem(.flexible(minimum: 120), spacing: 10)
        ]
    }

    func phraseCharacterTile(_ character: String) -> some View {
        let animationCharacter = animationCharacter(for: character)
        let strokeText = phraseTileStrokeText(for: animationCharacter)
        return Button {
            selectCharacterFromPhrase(animationCharacter)
        } label: {
            VStack(spacing: 6) {
                StrokeAnimationHeaderLabel(text: strokeText)
                    .frame(maxWidth: .infinity)

                StrokeOrderWebView(
                    character: animationCharacter,
                    reloadToken: StrokeAnimationToken.stable(for: "phrase-card-\(phrase)-\(animationCharacter)"),
                    canvasSize: 110
                )
                .frame(height: 118)
                .frame(maxWidth: .infinity)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 154)
            .background(Color(.secondarySystemBackground).opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color(.separator).opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(animationCharacter, pinyin: store.item(for: animationCharacter)?.pinyinText)
    }

    func phraseTileStrokeText(for character: String) -> String {
        guard let strokes = store.item(for: character)?.strokes else { return "" }
        let unit = strokes == 1 ? "stroke" : "strokes"
        return "\(strokes) \(unit)"
    }

    func animationCharacter(for character: String) -> String {
        let variants = [character] + store.allVariants(for: character).map(\.character)
        let preferred = variants.first { candidate in
            animationScript == "traditional"
                ? store.isTraditional(candidate)
                : store.isSimplified(candidate)
        }
        if let preferred {
            return preferred
        }
        if animationScript == "simplified" {
            let simplified = store.simplifiedText(character).trimmingCharacters(in: .whitespacesAndNewlines)
            if !simplified.isEmpty, store.item(for: simplified) != nil {
                return simplified
            }
        }
        return character
    }

    func selectCharacterFromPhrase(_ character: String) {
        store.speakCharacter(character)
        if let onSelectCharacter {
            onSelectCharacter(character)
            return
        }

        if store.route == .search && store.homeTab == .filter {
            store.previewPhraseCardCharacter(character, in: phrase, announce: false)
        } else {
            store.preview(character: character, announce: false)
        }
        onDone?()
    }
}
