import SwiftUI

struct PhraseTableSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let character: String
    let requiredCharacters: [String]
    let isVertical: Bool
    private let visiblePhraseRows = 6
    @State private var selectedPhrase: PhraseItem?
    @State private var showAddPhraseSheet = false

    init(character: String, isVertical: Bool, requiredCharacters: [String]? = nil) {
        self.character = character
        self.requiredCharacters = requiredCharacters ?? [character]
        self.isVertical = isVertical
    }

    private var isPhone: Bool {
        RadixPlatform.isPhone
    }

    private var isRunningOnMac: Bool {
        RadixPlatform.isRunningOnMac
    }

    @ViewBuilder
    private var copyHintLabel: some View {
        HStack(spacing: 4) {
            Text(isRunningOnMac ? "Right-click" : "Long-press")
            Image(systemName: "doc.on.doc")
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        let displayedPhrases = matchingPhrases
        VStack(alignment: .leading, spacing: 12) {
            if let selectedPhrase {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selectedPhrase = nil
                    }
                } label: {
                    Label("词Phrase", systemImage: "chevron.backward")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                PhraseInfoCard(phrase: selectedPhrase, onDone: {
                    dismiss()
                })
                    .environmentObject(store)
            } else {
                HStack(alignment: .center, spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Label("Phrase Library", systemImage: "text.quote")
                            .font(ResponsiveFont.headline.weight(.semibold))
                        Text("\(displayedPhrases.count) \(displayedPhrases.count == 1 ? "match" : "matches")")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        phraseScopeLabel
                    }
                    .layoutPriority(1)

                    Spacer()

                    Button {
                        showAddPhraseSheet = true
                    } label: {
                        Label("Phrase", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add Phrase")
                }
                .padding(12)
                .background(RadixTheme.secondaryBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8))

                HStack {
                    copyHintLabel
                    Spacer(minLength: 0)
                }

                PhraseLengthFilterChips(selection: store.phraseLengthBinding)

                if displayedPhrases.isEmpty {
                    ContentUnavailableView(
                        "No phrases found",
                        systemImage: "text.justify",
                        description: Text(emptyPhraseDescription)
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(displayedPhrases, id: \.id) { phrase in
                                PhraseTableRow(
                                    phrase: phrase,
                                    rowHeight: phraseRowHeight
                                ) {
                                    presentPhrase(phrase)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(height: phraseViewportHeight)
                    .background(RadixTheme.secondaryBackground.opacity(0.7))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                    Spacer(minLength: 0)
                }
                HStack {
                    Spacer()
                    DismissButton()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(PhraseTableDetentModifier(isPhone: isPhone))
        .sheet(isPresented: $showAddPhraseSheet) {
            AddPhraseSheet(returnTitle: "Phrase")
                .environmentObject(store)
        }
        .onAppear {
            if !isMultiCharacterLookup {
                store.refreshPhrases(for: character)
            }
        }
        .onChange(of: store.phraseLength) { _, _ in
            selectedPhrase = nil
            if !isMultiCharacterLookup {
                store.refreshPhrases(for: character)
            }
        }
    }

    private var matchingPhrases: [PhraseItem] {
        if isMultiCharacterLookup {
            return store.phraseMatches(for: requiredCharacters.joined(), length: store.phraseLength)
        }
        return store.phrases
    }

    private var isMultiCharacterLookup: Bool {
        Set(requiredCharacters).count > 1
    }

    @ViewBuilder
    private var phraseScopeLabel: some View {
        if isMultiCharacterLookup {
            Text("Containing \(requiredCharacters.joined(separator: " "))")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private var emptyPhraseDescription: String {
        if isMultiCharacterLookup {
            return "No \(store.activePhraseLengthFilterLabel)-length phrases contain matching parts of \(requiredCharacters.joined(separator: " "))."
        }
        return "No \(store.activePhraseLengthFilterLabel)-length phrases were found for \(character)."
    }

    private func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        withAnimation(.easeInOut(duration: 0.2)) {
            if isPhone {
                store.presentPhraseInSidebar(phrase)
                selectedPhrase = phrase
            } else {
                selectedPhrase = nil
                store.presentPhraseInSidebar(phrase)
            }
        }
    }

    private var phraseRowHeight: CGFloat {
        RadixPlatform.interfaceIdiom.phraseRowHeight
    }

    private var phraseViewportHeight: CGFloat {
        (phraseRowHeight * CGFloat(visiblePhraseRows)) + 5
    }
}

private struct PhraseTableRow: View {
    let phrase: PhraseItem
    let rowHeight: CGFloat
    let onSelect: () -> Void

    private var leadingColumnWidth: CGFloat {
        RadixPlatform.interfaceIdiom.phraseLeadingColumnWidth
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            PhraseSummaryTile(
                phrase: phrase,
                minimumHeight: pagePhraseTileHeight,
                maximumWidth: leadingColumnWidth,
                onSelect: onSelect
            )
            .frame(width: leadingColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: rowHeight, alignment: .leading)
        .background(RadixTheme.background.opacity(0.001))
        .phraseContextMenu(phrase)
    }

    private var pagePhraseTileHeight: CGFloat {
        RadixPlatform.interfaceIdiom.phraseTileHeight
    }
}

private struct PhraseTableDetentModifier: ViewModifier {
    let isPhone: Bool

    func body(content: Content) -> some View {
        if isPhone {
            content
                .presentationDetents([.large])
                .presentationDragIndicator(.visible)
        } else {
            content
        }
    }
}

struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button {
            dismiss()
        } label: {
            Image(systemName: "xmark")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .radixMinimumTapTarget()
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Close")
    }
}
