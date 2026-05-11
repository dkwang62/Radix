import SwiftUI

struct PhraseTableSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let character: String
    let isVertical: Bool
    private let visiblePhraseRows = 6
    @State private var selectedPhrase: PhraseItem?
    @State private var showAddPhraseSheet = false

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
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
        VStack(alignment: .leading, spacing: 12) {
            if let selectedPhrase {
                Button {
                    withAnimation(.easeInOut(duration: 0.2)) {
                        self.selectedPhrase = nil
                    }
                } label: {
                    Label("Phrases", systemImage: "chevron.backward")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)

                PhraseInfoCard(phrase: selectedPhrase, onDone: {
                    dismiss()
                })
                    .environmentObject(store)
            } else {
                copyHintLabel

                PhraseLengthFilterChips(selection: $store.phraseLength)

                if store.phrases.isEmpty {
                    ContentUnavailableView(
                        "No phrases found",
                        systemImage: "text.justify",
                        description: Text("No \(store.activePhraseLengthFilterLabel)-length phrases were found for \(character).")
                    )
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.phrases, id: \.id) { phrase in
                                PhraseTableRow(
                                    phrase: phrase,
                                    isPhone: isPhone,
                                    rowHeight: phraseRowHeight
                                ) {
                                    presentPhrase(phrase)
                                }
                                Divider()
                            }
                        }
                    }
                    .frame(height: phraseViewportHeight)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))

                    Spacer(minLength: 0)
                }

                HStack {
                    Button {
                        showAddPhraseSheet = true
                    } label: {
                        Label("Phrases", systemImage: "plus.circle.fill")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Add Phrases")

                    Spacer()
                    DismissButton()
                }
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(PhraseTableDetentModifier(isPhone: isPhone))
        .sheet(isPresented: $showAddPhraseSheet) {
            AddPhraseSheet(returnTitle: "Phrases")
                .environmentObject(store)
        }
        .onAppear {
            store.refreshPhrases(for: character)
        }
        .onChange(of: store.phraseLength) { _, _ in
            selectedPhrase = nil
            store.refreshPhrases(for: character)
        }
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
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return isPhone ? 72 : 82
        #endif
    }

    private var phraseViewportHeight: CGFloat {
        (phraseRowHeight * CGFloat(visiblePhraseRows)) + 5
    }
}

private struct PhraseTableRow: View {
    let phrase: PhraseItem
    let isPhone: Bool
    let rowHeight: CGFloat
    let onSelect: () -> Void

    private var leadingColumnWidth: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 150
        #else
        return isPhone ? 96 : 120
        #endif
    }

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
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
        .contentShape(Rectangle())
        .onTapGesture(perform: onSelect)
        .phraseContextMenu(phrase)
    }
}

private struct PhraseTableDetentModifier: ViewModifier {
    let isPhone: Bool

    func body(content: Content) -> some View {
        if isPhone {
            content
                .presentationDetents([.medium, .large])
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
        }
        .buttonStyle(.borderedProminent)
        .accessibilityLabel("Close")
    }
}
