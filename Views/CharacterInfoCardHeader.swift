import SwiftUI

extension CharacterInfoCard {
    func headerRow(
        characterSize: CGFloat,
        pinyinFont: Font
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            usageCharactersButton(characterSize: characterSize)

            Text(displayPinyin)
                .font(pinyinFont)
                .foregroundStyle(Color.orange)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Spacer(minLength: 0)
            favoritesButton
        }
    }

    var favoritesButton: some View {
        Button {
            store.setFavorite(character: item.character, isFavorite: !store.isFavorite(item.character))
        } label: {
            Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
                .foregroundStyle(store.isFavorite(item.character) ? .yellow : .secondary)
                .radixIconButtonSurface()
        }
        .buttonStyle(.plain)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
        .accessibilityLabel(store.isFavorite(item.character) ? "Remove from favorites" : "Add to favorites")
        .help(store.isFavorite(item.character) ? "Remove from favorites" : "Add to favorites")
    }

    var tierButton: some View {
        Button {
            showFrequencyGuide = true
        } label: {
            tierChip(for: item.tier)
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFrequencyGuide, arrowEdge: .bottom) {
            tierGuideView
                .applyCompactPopoverStyle()
        }
    }

    func usageCharactersButton(characterSize: CGFloat) -> some View {
        Button {
            guard item.usageCount > 1 else {
                activeChipGuide = .usageCount
                return
            }
            openComponentsPopover(component: item.character)
        } label: {
            characterTile(
                character: item.character,
                subtitle: usageCountSubtitle,
                size: characterTileSize,
                characterSize: characterSize,
                isHighlighted: false
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
        .popover(isPresented: chipGuideBinding(for: .usageCount), arrowEdge: .bottom) {
            chipGuideView(for: .usageCount)
                .applyCompactPopoverStyle()
        }
    }

    @ViewBuilder
    var referenceMetaRow: some View {
        if !structurePartsText.isEmpty || item.tier > 0 {
            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    tierButton
                    if !structurePartsText.isEmpty {
                        chipButton(structurePartsText, guide: .structure)
                    }
                    Spacer(minLength: 0)
                }

                VStack(alignment: .leading, spacing: 8) {
                    tierButton
                    if !structurePartsText.isEmpty {
                        chipButton(structurePartsText, guide: .structure)
                    }
                }
            }
        }
    }
}
