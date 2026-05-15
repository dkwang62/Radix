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
        HStack(alignment: .top, spacing: 18) {
            Text(item.character)
                .font(.system(size: 112))
                .lineLimit(1)
                .frame(width: 132, height: 132)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)

            VStack(alignment: .leading, spacing: 10) {
                Text(item.pinyinText.isEmpty ? "No pinyin" : item.pinyinText)
                    .font(ResponsiveFont.title2.bold())
                    .foregroundStyle(.secondary)
                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(ResponsiveFont.title3)
                    .fixedSize(horizontal: false, vertical: true)
                let allVariants = store.allVariants(for: item.character)
                if !allVariants.isEmpty {
                    HStack(spacing: 8) {
                        Text("Variants")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        ForEach(allVariants, id: \.character) { variant in
                            Button {
                                store.select(character: variant.character)
                                store.preview(character: variant.character)
                            } label: {
                                Text(variant.character)
                                    .font(ResponsiveFont.title3.weight(.semibold))
                                    .frame(width: 34, height: 34)
                            }
                            .buttonStyle(.plain)
                            .background(Color.accentColor.opacity(0.10))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                            .overlay(
                                RoundedRectangle(cornerRadius: 8)
                                    .stroke(Color.accentColor.opacity(0.25), lineWidth: 1)
                            )
                            .accessibilityLabel("Open variant \(variant.character)")
                        }
                    }
                }

                LazyVGrid(columns: [GridItem(.adaptive(minimum: 130), spacing: 8)], alignment: .leading, spacing: 8) {
                    characterMetric(
                        title: "Frequency",
                        value: item.rank.map { "Rank \($0)" } ?? "Unavailable",
                        systemImage: "chart.bar"
                    )
                    characterMetric(
                        title: "Strokes",
                        value: item.strokes.map { "\($0)" } ?? "Unknown",
                        systemImage: "pencil.line"
                    )
                    if !item.radical.isEmpty {
                        characterMetric(
                            title: "Radical",
                            value: item.radical,
                            systemImage: "square.split.2x2"
                        )
                    }
                }
            }
            Spacer(minLength: 0)
        }
        .padding(18)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color(.separator), lineWidth: 0.5)
        )
    }

    func characterMetric(title: String, value: String, systemImage: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.10))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                Text(title)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
