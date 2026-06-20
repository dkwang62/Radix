import SwiftUI

extension AddedPhraseReviewSheet {
    var selectedPhraseDetailCard: some View {
        VStack(alignment: .leading, spacing: 8) {
            if let phrase = selectedPhrase {
                phraseDetails(phrase)
            } else {
                PhraseReviewStatusCycleHint(usesPointer: RadixPlatform.isDesktop)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if selectedPhrase == nil, selectedTool == nil {
                Text("No status selected. Showing all phrases.")
                    .font(reviewCaptionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }

            if let visibleMessage {
                Text(visibleMessage)
                    .font(reviewCaptionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadixTheme.separator.opacity(0.35), lineWidth: 1)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func phraseDetails(_ phrase: PhraseItem) -> some View {
        VStack(alignment: .center, spacing: 2) {
            HStack(spacing: 8) {
                Text(phrase.word)
                    .font(.system(size: usesRegularReviewLayout ? 22 : 19, weight: .semibold))
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                    .fixedSize(horizontal: false, vertical: true)

                Label(reviewDetail(for: phrase), systemImage: statusIcon(for: phrase.reviewStatus))
                    .font(reviewCaptionFont.weight(.semibold))
                    .foregroundStyle(statusColor(for: phrase.reviewStatus))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .center)

            Text(phrase.pinyin.isEmpty ? "No pinyin yet" : phrase.pinyin)
                .font(reviewCaptionFont)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .multilineTextAlignment(.center)
                .frame(maxWidth: detailTextMaxWidth, alignment: .center)

            Text(phrase.meanings.isEmpty ? "No meaning yet" : phrase.meanings)
                .font(reviewCaptionFont)
                .foregroundStyle(phrase.meanings.isEmpty ? Color.secondary : Color.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
                .truncationMode(.tail)
                .frame(maxWidth: detailTextMaxWidth, alignment: .center)

        }
        .frame(maxWidth: .infinity, alignment: .center)
    }

    func reviewDetail(for phrase: PhraseItem) -> String {
        phrase.reviewStatus?.title ?? "New"
    }

    func statusIcon(for status: PhraseReviewStatus?) -> String {
        switch status {
        case .checked, .completed: return "checkmark.circle.fill"
        case .hidden: return "eye.slash.fill"
        case .removed: return "xmark.circle.fill"
        case nil: return "sparkle"
        }
    }

    func statusColor(for status: PhraseReviewStatus?) -> Color {
        switch status {
        case .checked, .completed: return Color.accentColor
        case .hidden: return Color.orange
        case .removed: return Color.red
        case nil: return Color.secondary
        }
    }

    var emptyStateView: some View {
        VStack(spacing: 10) {
            Image(systemName: "text.badge.checkmark")
                .font(.system(size: 44, weight: .semibold))
                .foregroundStyle(.secondary.opacity(0.55))

            Text(emptyTitle)
                .font(.system(size: usesRegularReviewLayout ? 22 : 19, weight: .semibold))
                .foregroundStyle(.primary)
                .multilineTextAlignment(.center)

            Text(emptyDescription)
                .font(reviewCaptionFont)
                .foregroundStyle(.secondary)
                .lineLimit(nil)
                .multilineTextAlignment(.center)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: 520)
        }
        .padding(.horizontal, 24)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }

    var emptyTitle: String {
        switch filter {
        case .new: return "No new phrases"
        case .checked: return "No checked phrases"
        case .hidden: return "No hidden phrases"
        case .removed: return "No rejected phrases"
        case .all: return "No active added phrases"
        }
    }

    var emptyDescription: String {
        switch filter {
        case .new: return "New means not checked, hidden, or rejected."
        case .checked: return "Checked phrases are accepted as useful phrases. You can still hide, reject, or restore them to New if needed."
        case .hidden: return "Hidden phrases stay useful on pages but stay out of the phrase library."
        case .removed: return "Rejected phrases are remembered as not-a-phrase groupings. Mark one New if you want to restore it."
        case .all: return "Added phrases with two or more characters appear here."
        }
    }
}
