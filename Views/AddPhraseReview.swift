import SwiftUI

struct AddPhraseReview: View {
    let addedPhrases: [PhraseDiscoveryCandidate]
    let message: String?
    let returnTitle: String
    let onAddMore: () -> Void
    let onDelete: (PhraseDiscoveryCandidate) -> Void
    let onReturn: () -> Void

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if addedPhrases.isEmpty {
                        emptyState
                    } else {
                        HStack(alignment: .center, spacing: 10) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(ResponsiveFont.title3)
                                .foregroundStyle(Color.green)

                            VStack(alignment: .leading, spacing: 2) {
                                Text("\(addedPhrases.count) Added")
                                    .font(ResponsiveFont.headline.weight(.semibold))
                                Text("Review the phrases saved to My Phrases.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .padding(12)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .background(Color.green.opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 8))

                        AddedPhraseResultList(candidates: addedPhrases, onDelete: onDelete)
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }

            Divider()

            actionRow
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    private var emptyState: some View {
        if let message {
            Text(message)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
        ContentUnavailableView(
            "No added phrases left",
            systemImage: "text.badge.xmark",
            description: Text("You deleted all phrases added in this round.")
        )
        .frame(maxWidth: .infinity, minHeight: 220)
    }

    private var actionRow: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 10) {
                addMoreButton
                Spacer()
                returnButton
            }

            VStack(spacing: 10) {
                returnButton
                addMoreButton
            }
        }
        .padding()
        .background(RadixTheme.background)
    }

    private var addMoreButton: some View {
        Button {
            onAddMore()
        } label: {
            Label("Add More", systemImage: "plus")
        }
        .buttonStyle(.bordered)
    }

    private var returnButton: some View {
        Button {
            onReturn()
        } label: {
            Label("Back to \(returnTitle)", systemImage: "arrow.uturn.backward")
        }
        .buttonStyle(.borderedProminent)
    }
}
