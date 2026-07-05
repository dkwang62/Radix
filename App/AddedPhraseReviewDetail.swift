import SwiftUI

extension AddedPhraseReviewSheet {
    var activeReviewPhraseWord: String? {
        selectedPhrase?.word ?? store.activeSidebarPhrasePreview?.word
    }

    @ViewBuilder
    var selectedPhraseDetailCard: some View {
        if let phrase = selectedPhrase, !usesRegularReviewLayout {
            VStack(alignment: .leading, spacing: 8) {
                phraseDetails(phrase)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.secondaryBackground.opacity(0.55))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator.opacity(0.35), lineWidth: 1)
            )
            .clipShape(RoundedRectangle(cornerRadius: 8))
        } else if let visibleMessage {
            VStack(alignment: .leading, spacing: 8) {
                Text(visibleMessage)
                    .font(reviewCaptionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.secondaryBackground.opacity(0.55))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    @ViewBuilder
    func phraseDetails(_ phrase: PhraseItem) -> some View {
        if usesRegularReviewLayout {
            HStack(spacing: 10) {
                Text(phrase.word)
                    .font(.system(size: 22, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)

                Label(reviewDetail(for: phrase), systemImage: statusIcon(for: phrase.reviewStatus))
                    .font(reviewCaptionFont.weight(.semibold))
                    .foregroundStyle(statusColor(for: phrase.reviewStatus))
                    .lineLimit(1)

                Text(phrase.pinyin.isEmpty ? "No pinyin yet" : phrase.pinyin)
                    .font(reviewCaptionFont)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Text(phrase.meanings.isEmpty ? "No meaning yet" : phrase.meanings)
                    .font(reviewCaptionFont)
                    .foregroundStyle(phrase.meanings.isEmpty ? Color.secondary : Color.primary)
                    .lineLimit(1)
                    .truncationMode(.tail)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        } else {
            VStack(alignment: .center, spacing: 1) {
                HStack(spacing: 8) {
                    Text(phrase.word)
                        .font(.system(size: 20, weight: .semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)

                    Label(reviewDetail(for: phrase), systemImage: statusIcon(for: phrase.reviewStatus))
                        .font(reviewCaptionFont.weight(.semibold))
                        .foregroundStyle(statusColor(for: phrase.reviewStatus))
                        .lineLimit(1)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                HStack(spacing: 8) {
                    Text(phrase.pinyin.isEmpty ? "No pinyin yet" : phrase.pinyin)
                        .foregroundStyle(.secondary)

                    Text(phrase.meanings.isEmpty ? "No meaning yet" : phrase.meanings)
                        .foregroundStyle(phrase.meanings.isEmpty ? Color.secondary : Color.primary)
                }
                .font(reviewCaptionFont)
                .lineLimit(1)
                .truncationMode(.tail)
                .frame(maxWidth: detailTextMaxWidth, alignment: .center)
            }
            .frame(maxWidth: .infinity, alignment: .center)
        }
    }

    func reviewDetail(for phrase: PhraseItem) -> String {
        phrase.reviewStatus?.title ?? "Unreviewed"
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
        case .new: return "No unreviewed phrases"
        case .checked: return "No accepted phrases"
        case .hidden: return "No hidden phrases"
        case .removed: return "No rejected phrases"
        case .all: return "No active added phrases"
        }
    }

    var emptyDescription: String {
        switch filter {
        case .new: return "Unreviewed phrases are waiting for you to decide whether to accept, hide, or reject them."
        case .checked: return "Accepted phrases are useful phrases. You can still hide, reject, or mark them Unreviewed later."
        case .hidden: return "Hidden phrases stay useful on pages but stay out of the phrase library."
        case .removed: return "Rejected phrases are remembered as not-a-phrase groupings. Mark one Unreviewed if you want to reconsider it."
        case .all: return "Added phrases with two or more characters appear here."
        }
    }
}
