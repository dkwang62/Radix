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
        ScrollView {
            phrasePageGridContent
                .padding(.vertical, 4)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .scrollIndicators(usesRegularReviewLayout ? .automatic : .visible)
    }

    var phrasePageGridContent: some View {
        LazyVGrid(
            columns: phraseReviewColumns,
            alignment: .center,
            spacing: 6
        ) {
            ForEach(pagedPhrases) { phrase in
                AddedPhraseReviewTile(
                    phrase: phrase,
                    isSelected: selectedPhrase?.word == phrase.word,
                    onSelect: { applySelectedTool(to: phrase) },
                    onMarkNew: { setStatus(nil, for: phrase) },
                    onCheck: { setStatus(.checked, for: phrase) },
                    onHide: { setStatus(.hidden, for: phrase) },
                    onReject: { setStatus(.removed, for: phrase) },
                    showsStatusActions: true
                )
            }
        }
        .padding(.vertical, 2)
        .padding(.horizontal, usesRegularReviewLayout ? 10 : 0)
        .frame(maxWidth: usesRegularReviewLayout ? 920 : 520, alignment: .center)
        .frame(maxWidth: .infinity)
    }

    var phraseReviewColumns: [GridItem] {
        if !usesRegularReviewLayout {
            return Array(
                repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 6, alignment: .center),
                count: 3
            )
        }

        return Array(
            repeating: GridItem(.flexible(minimum: 0, maximum: .infinity), spacing: 8, alignment: .center),
            count: 4
        )
    }
}

struct AddedPhraseReviewTile: View {
    let phrase: PhraseItem
    let isSelected: Bool
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
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.62)
                    .frame(maxWidth: .infinity, minHeight: 38)
                    .padding(.horizontal, 5)

                Image(systemName: statusIcon)
                    .font(.system(size: 9, weight: .bold))
                    .foregroundStyle(statusColor)
                    .padding(3)
            }
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
