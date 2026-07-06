import SwiftUI

extension CharacterInfoCard {
    func chipButton(_ text: String, guide: ChipGuide) -> some View {
        Button {
            activeChipGuide = guide
        } label: {
            chip(text)
        }
        .buttonStyle(.plain)
        .popover(isPresented: chipGuideBinding(for: guide), arrowEdge: .bottom) {
            chipGuideView(for: guide)
                .applyCompactPopoverStyle()
        }
    }

    func openComponentsPopover(component: String?) {
        selectedPopupComponent = component ?? item.character
        showComponentsPopover = true
    }

    var cardComponents: [ComponentItem] {
        store.components(for: item.character)
    }

    @ViewBuilder
    var componentIconStrip: some View {
        if !cardComponents.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Label("Components", systemImage: "puzzlepiece.extension")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    GlossaryTermButton(term: "Components")
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    ForEach(Array(componentRows.enumerated()), id: \.offset) { _, rowComponents in
                        HStack(spacing: 6) {
                            ForEach(rowComponents, id: \.character) { component in
                                componentIconButton(component)
                            }
                        }
                    }
                }
            }
            .padding(10)
            .background(RadixTheme.secondaryBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var componentColumnCount: Int {
        isPhone ? 2 : 3
    }

    var componentRows: [[ComponentItem]] {
        stride(from: 0, to: cardComponents.count, by: componentColumnCount).map { start in
            let end = min(start + componentColumnCount, cardComponents.count)
            return Array(cardComponents[start..<end])
        }
    }

    @ViewBuilder
    func componentIconButton(_ component: ComponentItem) -> some View {
        let isRadical = component.character == item.radical
        Button {
            openComponentsPopover(component: component.character)
        } label: {
            characterTile(
                character: component.character,
                subtitle: component.pinyinText.isEmpty ? nil : component.pinyinText,
                size: componentTileSize,
                characterSize: componentCharacterFontSize,
                isHighlighted: isRadical
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(component.character, pinyin: component.pinyinText)
    }

    func characterTile(
        character: String,
        subtitle: String?,
        size: CGFloat,
        characterSize: CGFloat,
        isHighlighted: Bool
    ) -> some View {
        CharacterInfoTile(
            character: character,
            subtitle: subtitle,
            size: size,
            characterSize: characterSize,
            isHighlighted: isHighlighted
        )
    }
}
