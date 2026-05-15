import SwiftUI

struct PhraseDiscoverySummaryGrid: View {
    let sourceTitle: String
    let sourceCount: Int
    let stats: PhraseDiscoveryStats
    let newCount: Int
    let selectedCount: Int

    var body: some View {
        LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            DiscoveryStatChip(title: sourceTitle, value: sourceCount)
            DiscoveryStatChip(title: "Read", value: stats.totalParsed)
            DiscoveryStatChip(title: "Duplicates", value: stats.duplicatesRemoved)
            DiscoveryStatChip(title: "Existing", value: stats.alreadyExisting)
            DiscoveryStatChip(title: "Invalid", value: stats.invalidLines)
            DiscoveryStatChip(title: "New", value: newCount)
            DiscoveryStatChip(title: "Selected", value: selectedCount)
        }
    }
}

struct CaptureWorkflowProgressView: View {
    let steps: [CaptureWorkflowStep]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Phrases Steps")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(steps) { step in
                    CaptureWorkflowStepChip(step: step)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PhraseDiscoveryCandidateList: View {
    let candidates: [PhraseDiscoveryCandidate]
    let binding: (PhraseDiscoveryCandidate) -> Binding<PhraseDiscoveryCandidate>

    var body: some View {
        VStack(spacing: 0) {
            ForEach(candidates) { candidate in
                PhraseDiscoveryCandidateRow(candidate: binding(candidate))
                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct AddedPhraseResultList: View {
    let candidates: [PhraseDiscoveryCandidate]
    let onDelete: (PhraseDiscoveryCandidate) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Label("Added to My Phrases", systemImage: "text.badge.checkmark")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(candidates) { candidate in
                    AddedPhraseResultRow(candidate: candidate, onDelete: onDelete)
                    Divider()
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }
}
