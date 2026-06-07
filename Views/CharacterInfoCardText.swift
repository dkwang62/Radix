import SwiftUI

extension CharacterInfoCard {
    var displayPinyin: String {
        let joined = item.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "—" : joined
    }

    var structurePartsText: String {
        item.decomposition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var etymologyText: String {
        [item.etymologyHint, item.etymologyDetails]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var notesText: String {
        item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var tierColor: Color {
        switch item.tier {
        case 1: return .green
        case 2: return .teal
        case 3: return .blue
        case 4: return .orange
        default: return .secondary
        }
    }

    var tierRecommendation: String {
        switch item.tier {
        case 1: return "Core Literacy"
        case 2: return "Fluency Core"
        case 3: return "Educated Native"
        case 4: return "Academic/Pro"
        default: return "Niche/Rare"
        }
    }

    var definitionAndNotes: some View {
        VStack(alignment: .leading, spacing: 10) {
            VStack(alignment: .leading, spacing: 6) {
                HStack(spacing: 4) {
                    Label("Definition", systemImage: "text.book.closed")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    GlossaryTermButton(term: "Definition")
                }

                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(ResponsiveFont.subheadline)
                    .foregroundStyle(.primary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.secondaryBackground.opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))

            if !etymologyText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Label("Origin", systemImage: "sparkle.magnifyingglass")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        GlossaryTermButton(term: "Origin")
                    }

                    Text(etymologyText)
                        .font(ResponsiveFont.footnote)
                        .italic()
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.secondaryBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            if !notesText.isEmpty {
                VStack(alignment: .leading, spacing: 6) {
                    HStack(spacing: 4) {
                        Label("Notes", systemImage: "note.text")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                        GlossaryTermButton(term: "Notes")
                    }
                    Text(notesText)
                        .font(ResponsiveFont.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.secondaryBackground.opacity(0.35))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}
