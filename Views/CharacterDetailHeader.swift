import SwiftUI

extension CharacterDetailView {
    var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sizeClass == .compact {
                compactHeader
            } else {
                regularHeader
            }
        }
    }

    /// iPhone / compact split-view header: animated stroke order + info card.
    var compactHeader: some View {
        CharacterPreviewHeader(
            character: item.character,
            showClearButton: false,
            isVertical: true
        )
        .padding(.bottom, 8)
    }

    /// iPad / Mac regular header: large static character + pinyin + definition + variant buttons.
    var regularHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.character)
                .font(.system(size: 112))
                .lineLimit(1)
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.pinyinText.isEmpty ? "No pinyin" : item.pinyinText)
                    .font(ResponsiveFont.title2)
                    .foregroundStyle(.secondary)
                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(ResponsiveFont.title3)
                let allVariants = store.allVariants(for: item.character)
                if !allVariants.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(allVariants, id: \.character) { variant in
                            Button {
                                store.select(character: variant.character)
                                store.preview(character: variant.character)
                            } label: {
                                Text("Variant: \(variant.character)")
                                    .font(ResponsiveFont.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }
}
