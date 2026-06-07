import SwiftUI

struct CharacterPhraseLookupSection: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    var onDone: (() -> Void)?
    @State private var selectedPhrase: PhraseItem?

    private let visiblePhraseRows = 6

    private var isRunningOnMac: Bool {
        RadixPlatform.isRunningOnMac
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                PhraseLengthFilterChips(selection: $store.phraseLength)
                Spacer()
                Button {
                    finishLookup()
                } label: {
                    Image(systemName: "xmark")
                }
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .accessibilityLabel("Close")
            }

            copyHintLabel

            if store.phrases.isEmpty {
                Text("No phrases found.")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.phrases, id: \.id) { phrase in
                                phraseRow(phrase: phrase)
                                Divider()
                            }
                        }
                    }
                    .frame(height: phraseViewportHeight)
                }
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }

        }
        .sheet(item: phonePhraseSheetBinding) { phrase in
            NavigationStack {
                PhraseInfoCard(phrase: phrase, onDone: finishLookup)
                    .environmentObject(store)
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
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

    private func phraseRow(phrase: PhraseItem) -> some View {
        let characterColumnWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 150
            #else
            return 120
            #endif
        }()

        return HStack(alignment: .top, spacing: 8) {
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
            .frame(width: characterColumnWidth, alignment: .leading)

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
        .frame(maxWidth: .infinity, minHeight: phraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .onTapGesture {
            presentPhrase(phrase)
        }
        .phraseContextMenu(phrase)
    }

    private var isPhone: Bool {
        RadixPlatform.isPhone
    }

    private var phonePhraseSheetBinding: Binding<PhraseItem?> {
        Binding(
            get: { isPhone ? selectedPhrase : nil },
            set: { newValue in
                if isPhone {
                    selectedPhrase = newValue
                }
            }
        )
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

    private func finishLookup() {
        selectedPhrase = nil
        store.dismissSidebarPhrasePreview()
        if let onDone {
            onDone()
        } else {
            dismiss()
        }
    }

    private var phraseRowHeight: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return 76
        #endif
    }

    private var phraseViewportHeight: CGFloat {
        (phraseRowHeight * CGFloat(visiblePhraseRows)) + 5
    }
}

struct PhraseLengthFilterChips: View {
    @Binding var selection: Int?

    private let options: [Int?] = [nil, 2, 3, 4, 5, 6, 7]

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                ForEach(Array(options.enumerated()), id: \.offset) { _, option in
                    Button {
                        selection = option
                    } label: {
                        Text(label(for: option))
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .padding(.horizontal, 10)
                            .padding(.vertical, 6)
                            .background(selection == option ? Color.accentColor : RadixTheme.secondaryBackground)
                            .foregroundStyle(selection == option ? Color.white : Color.primary)
                            .clipShape(Capsule())
                    }
                    .buttonStyle(.plain)
                    .accessibilityLabel(option.map { $0 >= 7 ? "7 or more characters" : "\($0) characters" } ?? "All phrase lengths")
                }
            }
            .padding(.vertical, 1)
        }
    }

    private func label(for option: Int?) -> String {
        guard let option else { return "All" }
        return option >= 7 ? "7+" : "\(option)"
    }
}
