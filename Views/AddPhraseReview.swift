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
                        Text("\(addedPhrases.count) added to My Phrases. Delete any you do not want to keep.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

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
        HStack {
            Button("Add More", action: onAddMore)
                .buttonStyle(.bordered)

            Spacer()

            Button("Back to \(returnTitle)", action: onReturn)
                .buttonStyle(.borderedProminent)
        }
        .padding()
        .background(Color(.systemBackground))
    }
}
