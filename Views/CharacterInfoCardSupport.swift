import SwiftUI

struct CharacterInfoTile: View {
    let character: String
    let subtitle: String?
    let size: CGFloat
    let characterSize: CGFloat
    let isHighlighted: Bool

    var body: some View {
        VStack(spacing: 2) {
            Text(character)
                .font(.system(size: characterSize, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: size, height: size)
        .background(isHighlighted ? Color.orange.opacity(0.18) : RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? Color.orange.opacity(0.75) : RadixTheme.separator, lineWidth: isHighlighted ? 1.5 : 0.5)
        )
    }
}

struct CharacterLearningTierGuide: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Character Learning Guide")
                .font(ResponsiveFont.headline)

            guideRow(tier: "Tier 1", label: "Core Literacy", desc: "Everyday survival. Essential for everyone.")
            guideRow(tier: "Tier 2", label: "Fluency Core", desc: "Reading newspapers,  media")
            guideRow(tier: "Tier 3", label: "Educated Native", desc: "University-level reading, formal writing")
            guideRow(tier: "Tier 4", label: "Academic", desc: "Specialized, technical, research-heavy")
            guideRow(tier: "Tier 5", label: "Niche/Rare", desc: "Rare names, dialect, archaic forms")
        }
        .font(ResponsiveFont.subheadline)
        .padding(16)
        .frame(maxWidth: 380, alignment: .leading)
    }

    private func guideRow(tier: String, label: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(tier): \(label)")
                .fontWeight(.bold)
            Text(desc)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}

enum ChipGuide: String, Identifiable {
    case usageCount
    case structure
    case radical

    var id: String { rawValue }

    func description(for item: ComponentItem) -> String {
        switch self {
        case .usageCount:
            if item.usageCount <= 1 {
                return "Not present in other characters."
            }
            return "Present in \(item.usageCount) characters."
        case .structure:
            return "How the character is built from components."
        case .radical:
            return "Dictionary indexing radical."
        }
    }
}
