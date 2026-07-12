import SwiftUI

struct SentenceExampleListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore

    let title: String
    let examples: [SentenceExampleRecord]
    @State private var usesTraditionalScript = RadixStudyPreferences.usesTraditionalScript

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(spacing: 0) {
                    ForEach(Array(examples.enumerated()), id: \.element.id) { index, example in
                        sentenceRow(example, rank: index + 1)
                    }
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
            }
            .background(RadixTheme.secondaryBackground.opacity(0.3))
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .primaryAction) {
                    CompactScriptToggle(
                        isTraditional: usesTraditionalScript,
                        accessibilityLabel: "Example sentence script",
                        minWidth: 34,
                        height: 28
                    ) {
                        usesTraditionalScript.toggle()
                        RadixStudyPreferences.usesTraditionalScript = usesTraditionalScript
                    }
                    .fixedSize(horizontal: true, vertical: false)
                }
            }
        }
        .presentationDetents([.medium, .large])
    }

    private func displayText(_ value: String) -> String {
        ConversationPracticeScriptSupport.displayText(
            value,
            usesTraditionalScript: usesTraditionalScript,
            store: store
        )
    }

    private func sentenceRow(_ example: SentenceExampleRecord, rank: Int) -> some View {
        Button {
            present(example, rank: rank)
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Text("\(rank)")
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .frame(width: 28, height: 28)
                    .radixSurface(RadixAccent.primary.opacity(0.1))

                VStack(alignment: .leading, spacing: 2) {
                    Text(displayText(example.chinese))
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.86)

                    if let english = example.english?.trimmingCharacters(in: .whitespacesAndNewlines),
                       !english.isEmpty {
                        Text(english)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                            .minimumScaleFactor(0.86)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)

                RadixCompactChevronLabel(
                    chevronSystemName: "chevron.right",
                    chevronFont: .system(size: RadixIconSize.small, weight: .semibold),
                    chevronForegroundStyle: .secondary,
                    chevronOpacity: 1
                )
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 9)
            .frame(maxWidth: .infinity, minHeight: 46, alignment: .leading)
            .radixSurface(RadixTheme.background)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Open sentence \(displayText(example.chinese))")
        .accessibilityHint("Opens the sentence information card.")
    }

    private func present(_ example: SentenceExampleRecord, rank: Int) {
        let item = ConversationPracticeItem(sentenceExample: example, rank: rank)
        store.presentSentencePreviewInSidebar(
            item,
            usesTraditionalScript: usesTraditionalScript,
            speak: false
        )
        dismiss()
    }
}
