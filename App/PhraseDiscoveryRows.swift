import SwiftUI

struct CaptureWorkflowStepChip: View {
    let step: CaptureWorkflowStep

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.systemImage)
                .font(ResponsiveFont.caption)
                .foregroundStyle(step.isComplete ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                Text(step.detail)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(step.isComplete ? Color.green.opacity(0.12) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isComplete ? Color.green.opacity(0.35) : Color(.separator), lineWidth: 0.5)
        )
    }
}

struct PhraseDiscoveryCandidateRow: View {
    @Binding var candidate: PhraseDiscoveryCandidate

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: $candidate.isSelected) {
                Text(candidate.phrase.isEmpty ? "Phrase" : candidate.phrase)
                    .font(ResponsiveFont.body.bold())
            }

            HStack(alignment: .top, spacing: 8) {
                PhraseDiscoveryField("Phrase") {
                    TextField("Phrase", text: $candidate.phrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                PhraseDiscoveryField("Pinyin") {
                    TextField("Pinyin", text: $candidate.pinyin)
                        .textFieldStyle(.roundedBorder)
                }
            }

            PhraseDiscoveryField("English Meaning") {
                TextField("Meaning", text: $candidate.meaning)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(10)
    }
}

struct AddedPhraseResultRow: View {
    let candidate: PhraseDiscoveryCandidate
    let onDelete: (PhraseDiscoveryCandidate) -> Void

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.phrase)
                    .font(ResponsiveFont.body.bold())
                if !candidate.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(candidate.pinyin)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                if !candidate.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(candidate.meaning)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Delete", role: .destructive) {
                onDelete(candidate)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))
        }
        .padding(8)
    }
}

struct DiscoveryStatChip: View {
    let title: String
    let value: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

struct PhraseDiscoveryField<Content: View>: View {
    let title: String
    @ViewBuilder let content: () -> Content

    init(_ title: String, @ViewBuilder content: @escaping () -> Content) {
        self.title = title
        self.content = content
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}
