import SwiftUI

extension AddedPhraseReviewSheet {
    var phraseGrid: some View {
        VStack(spacing: 6) {
            phrasePageGrid
            pageFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    @ViewBuilder
    var phrasePageGrid: some View {
        phrasePageGridContent
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    var phrasePageGridContent: some View {
        VStack(spacing: phraseGridSpacing) {
            ForEach(Array(phraseReviewRows.enumerated()), id: \.offset) { _, rowPhrases in
                HStack(spacing: phraseGridColumnSpacing) {
                    ForEach(rowPhrases) { phrase in
                        AddedPhraseReviewTile(
                            phrase: phrase,
                            isSelected: activeReviewPhraseWord == phrase.word,
                            height: phraseTileHeight,
                            onSelect: { applySelectedTool(to: phrase) },
                            onMarkNew: { setStatus(nil, for: phrase) },
                            onCheck: { setStatus(.checked, for: phrase) },
                            onHide: { setStatus(.hidden, for: phrase) },
                            onReject: { setStatus(.removed, for: phrase) },
                            showsStatusActions: true
                        )
                    }

                    ForEach(0..<phraseReviewPlaceholderCount(for: rowPhrases), id: \.self) { _ in
                        Color.clear
                            .frame(maxWidth: .infinity)
                            .frame(height: phraseTileHeight)
                    }
                }
            }
        }
        .padding(.horizontal, usesRegularReviewLayout ? 6 : 0)
        .frame(maxWidth: usesRegularReviewLayout ? 920 : 520, maxHeight: .infinity, alignment: .top)
        .frame(maxWidth: .infinity)
    }

    var phraseGridColumnSpacing: CGFloat {
        usesRegularReviewLayout ? 7 : 6
    }

    var phraseReviewRows: [[PhraseItem]] {
        stride(from: 0, to: pagedPhrases.count, by: phraseReviewColumnCount).map { start in
            let end = min(start + phraseReviewColumnCount, pagedPhrases.count)
            return Array(pagedPhrases[start..<end])
        }
    }

    func phraseReviewPlaceholderCount(for row: [PhraseItem]) -> Int {
        max(0, phraseReviewColumnCount - row.count)
    }
}

struct AddedPhraseReviewTile: View {
    let phrase: PhraseItem
    let isSelected: Bool
    let height: CGFloat
    let onSelect: () -> Void
    let onMarkNew: () -> Void
    let onCheck: () -> Void
    let onHide: () -> Void
    let onReject: () -> Void
    let showsStatusActions: Bool

    var body: some View {
        Button(action: onSelect) {
            ZStack(alignment: .topTrailing) {
                Text(phrase.word)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: .infinity)
                    .padding(.horizontal, 5)

                Image(systemName: statusIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(3)
            }
            .frame(maxWidth: .infinity)
            .frame(height: height)
            .background(tileFill)
            .overlay(
                RoundedRectangle(cornerRadius: 7)
                    .stroke(tileStroke, lineWidth: isSelected ? 2 : 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 7))
        }
        .buttonStyle(.plain)
        .contextMenu {
            if showsStatusActions {
                if phrase.reviewStatus != nil {
                    Button("Unreviewed", action: onMarkNew)
                }
                Button("Accepted", action: onCheck)
                    .disabled(phrase.reviewStatus == .checked)
                Button("Hide", action: onHide)
                    .disabled(phrase.reviewStatus == .hidden)
                Button("Reject", role: .destructive, action: onReject)
                    .disabled(phrase.reviewStatus == .removed)
            }
        }
        .accessibilityLabel(accessibilityText)
    }

    private var statusIcon: String {
        switch phrase.reviewStatus {
        case .checked, .completed: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case nil: return "circle.fill"
        }
    }

    private var statusColor: Color {
        switch phrase.reviewStatus {
        case .checked, .completed: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case nil: return Color.secondary.opacity(0.45)
        }
    }

    private var tileFill: Color {
        switch phrase.reviewStatus {
        case .checked, .completed:
            return Color.accentColor.opacity(0.14)
        case .hidden:
            return Color.orange.opacity(0.13)
        case .removed:
            return Color.red.opacity(0.10)
        case nil:
            return RadixTheme.secondaryBackground
        }
    }

    private var tileStroke: Color {
        if isSelected { return Color.accentColor }
        switch phrase.reviewStatus {
        case .checked, .completed:
            return Color.accentColor.opacity(0.45)
        case .hidden:
            return Color.orange.opacity(0.38)
        case .removed:
            return Color.red.opacity(0.34)
        case nil:
            return RadixTheme.separator.opacity(0.35)
        }
    }

    private var accessibilityText: String {
        let status = phrase.reviewStatus?.title ?? "Unreviewed"
        let meaning = phrase.meanings.isEmpty ? "No meaning" : phrase.meanings
        return "\(phrase.word), \(status), \(meaning)"
    }
}
