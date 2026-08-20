import SwiftUI

extension PhraseInfoCard {
    @ViewBuilder
    var phraseAnimationPicker: some View {
        let characters = phraseCharacters
        if !characters.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                if characters.count > 4 {
                    HStack {
                        Spacer(minLength: 0)
                        phraseAnimationPageStepper(characters)
                    }
                }
                phraseAnimationPageButtons(characters)
                phraseAnimationTileGrid(characters)
            }
            .padding(10)
            .background(RadixTheme.secondaryBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    func phraseAnimationPageStepper(_ characters: [String]) -> some View {
        let pageCount = phraseAnimationPageCount(for: characters)
        let safePage = phraseAnimationSafePage(for: characters)
        return HStack(spacing: 6) {
            phraseAnimationStepButton(
                systemName: "chevron.left",
                isEnabled: safePage > 0,
                accessibilityLabel: "Previous character group"
            ) {
                let newPage = max(safePage - 1, 0)
                selectedAnimationPage = newPage
                speakPhraseAnimationPage(newPage, characters: characters)
            }

            Text("\(safePage + 1)/\(pageCount)")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 34)

            phraseAnimationStepButton(
                systemName: "chevron.right",
                isEnabled: safePage < pageCount - 1,
                accessibilityLabel: "Next character group"
            ) {
                let newPage = min(safePage + 1, pageCount - 1)
                selectedAnimationPage = newPage
                speakPhraseAnimationPage(newPage, characters: characters)
            }
        }
    }

    func phraseAnimationStepButton(
        systemName: String,
        isEnabled: Bool,
        accessibilityLabel: String,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            RadixCompactChevronLabel(
                chevronSystemName: systemName,
                chevronFont: .system(size: 12, weight: .bold),
                chevronOpacity: 1,
                width: 26,
                height: 26
            )
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(isEnabled ? RadixAccent.primary : Color.secondary.opacity(0.45))
        .disabled(!isEnabled)
        .accessibilityLabel(accessibilityLabel)
    }

    @ViewBuilder
    func phraseAnimationPageButtons(_ characters: [String]) -> some View {
        let pageCount = phraseAnimationPageCount(for: characters)
        if pageCount > 1 {
            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 6) {
                    ForEach(0..<pageCount, id: \.self) { page in
                        phraseAnimationPageButton(page: page, characters: characters)
                    }
                }
                .padding(.vertical, 1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    func phraseAnimationPageButton(page: Int, characters: [String]) -> some View {
        let isSelected = selectedAnimationPage == page
        let label = phraseAnimationPageLabel(page: page, characters: characters)
        return Button {
            selectedAnimationPage = page
            store.speakCharacters(in: label)
        }
        label: {
            Text(label)
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .foregroundStyle(isSelected ? Color.white : Color.primary)
                .background(isSelected ? RadixAccent.primary : RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(RadixAccent.primary.opacity(isSelected ? 0 : 0.35), lineWidth: 1)
                )
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Show phrase characters \(label)")
    }

    func phraseAnimationTileGrid(_ characters: [String]) -> some View {
        let safePage = phraseAnimationSafePage(for: characters)
        let pageCharacters = phraseAnimationCharacters(on: safePage, from: characters)
        return VStack(spacing: 10) {
            ForEach(Array(phraseAnimationRows(for: pageCharacters).enumerated()), id: \.offset) { _, rowCharacters in
                HStack(spacing: 10) {
                    ForEach(rowCharacters, id: \.self) { character in
                        phraseCharacterTile(character)
                    }

                    if rowCharacters.count == 1 {
                        Color.clear
                            .frame(maxWidth: .infinity, minHeight: 154)
                    }
                }
            }
        }
    }

    func phraseAnimationRows(for characters: [String]) -> [[String]] {
        stride(from: 0, to: characters.count, by: 2).map { start in
            let end = min(start + 2, characters.count)
            return Array(characters[start..<end])
        }
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
                    reloadToken: StrokeAnimationToken.stable(for: "phrase-card-\(phrase.id)-\(animationCharacter)"),
                    canvasSize: 110
                )
                .frame(height: 118)
                .frame(maxWidth: .infinity)
            }
            .padding(8)
            .frame(maxWidth: .infinity, minHeight: 154)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator.opacity(0.6), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(
            animationCharacter,
            pinyin: store.item(for: animationCharacter)?.pinyinText,
            onAddToHistory: {
                store.recordInspectedCharacterInHistory(animationCharacter)
            }
        )
    }

    func phraseAnimationPageCount(for characters: [String]) -> Int {
        max(1, Int(ceil(Double(characters.count) / 4.0)))
    }

    func phraseAnimationSafePage(for characters: [String]) -> Int {
        min(selectedAnimationPage, max(phraseAnimationPageCount(for: characters) - 1, 0))
    }

    func phraseAnimationCharacters(on page: Int, from characters: [String]) -> [String] {
        let start = page * 4
        guard start < characters.count else { return Array(characters.prefix(4)) }
        let end = min(start + 4, characters.count)
        return Array(characters[start..<end])
    }

    func phraseAnimationPageLabel(page: Int, characters: [String]) -> String {
        phraseAnimationCharacters(on: page, from: characters).joined()
    }

    func speakPhraseAnimationPage(_ page: Int, characters: [String]) {
        let label = phraseAnimationPageLabel(page: page, characters: characters)
        store.speakCharacters(in: label)
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
        if isPracticeSentence {
            store.recordInspectedCharacterInHistory(character)
            return
        }
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
