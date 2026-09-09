import SwiftUI

struct SentenceExampleListSheet: View {
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var store: RadixStore

    let title: String
    let lookup: SentenceExampleLookup
    @State private var usesTraditionalScript = RadixStudyPreferences.usesTraditionalScript
    @State private var examples: [SentenceExampleRecord] = []
    @State private var nextOffset: Int?
    @State private var isInitialLoading = true
    @State private var isLoadingMore = false
    @State private var loadGeneration = UUID()

    private let pageSize = 24

    var body: some View {
        NavigationStack {
            Group {
                if isInitialLoading {
                    ProgressView("Loading examples...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if examples.isEmpty {
                    ContentUnavailableView {
                        Label("No Examples", systemImage: "text.page.slash")
                    } description: {
                        Text(emptyStateMessage)
                    }
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(Array(examples.enumerated()), id: \.element.id) { index, example in
                                sentenceRow(example, rank: index + 1)
                            }

                            if let nextOffset {
                                ProgressView()
                                    .frame(maxWidth: .infinity)
                                    .padding(.vertical, 16)
                                    .task(id: nextOffset) {
                                        await loadMore(from: nextOffset)
                                    }
                            }
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                    }
                }
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
        .task(id: SentenceExampleLoadID(lookup: lookup, revision: store.favoriteSentenceRevision)) {
            await reloadExamples()
        }
    }

    private var emptyStateMessage: String {
        switch lookup {
        case .character(let character):
            return "No saved sentence examples contain \(character)."
        case .phrase(let phrase):
            return "No saved sentence examples contain \(phrase)."
        }
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

    @MainActor
    private func reloadExamples() async {
        let generation = UUID()
        loadGeneration = generation
        isInitialLoading = true
        isLoadingMore = false
        examples = []
        nextOffset = nil

        let page = await loadPage(offset: 0)
        guard !Task.isCancelled, loadGeneration == generation else { return }
        examples = page.records
        nextOffset = page.nextOffset
        isInitialLoading = false
    }

    @MainActor
    private func loadMore(from offset: Int) async {
        guard !isLoadingMore, nextOffset == offset else { return }
        let generation = loadGeneration
        isLoadingMore = true
        let page = await loadPage(offset: offset)
        guard !Task.isCancelled, loadGeneration == generation else { return }
        examples.append(contentsOf: page.records)
        nextOffset = page.nextOffset
        isLoadingMore = false
    }

    private func loadPage(offset: Int) async -> SentenceExampleLookupPage {
        let lookup = lookup
        let pageSize = pageSize
        return await Task.detached(priority: .userInitiated) {
            RadixStudyPreferences.sentenceExamplePage(
                matching: lookup,
                offset: offset,
                limit: pageSize
            )
        }.value
    }
}

private struct SentenceExampleLoadID: Equatable {
    let lookup: SentenceExampleLookup
    let revision: Int
}
