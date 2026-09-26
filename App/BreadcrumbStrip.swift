import SwiftUI

struct BreadcrumbStrip: View {
    @EnvironmentObject private var store: RadixStore
    @State private var showsEmptyClipboardAlert = false
    @State private var isAddingFromClipboard = false

    private var activeMemoryItem: String? {
        if let phrase = store.activeSidebarPhrasePreview {
            return phrase.word
        }
        if store.route == .search && store.homeTab == .dataEdit {
            let editingCharacter = store.dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
            if !editingCharacter.isEmpty {
                return editingCharacter
            }
        }
        return store.previewCharacter
    }

    private var visibleHistoryItems: [String] {
        HistoryStripDisplayPolicy.visibleItems(from: store.rootBreadcrumb)
    }

    var body: some View {
        if shouldShowStrip {
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Button {
                        addFromClipboard()
                    } label: {
                        Image(systemName: "clipboard")
                            .font(.system(size: 17, weight: .semibold))
                            .frame(width: 44, height: 44)
                            .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)
                    .disabled(isAddingFromClipboard)
                    .accessibilityLabel("Add from clipboard")
                    .help("Add from clipboard")

                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 6) {
                            ForEach(Array(visibleHistoryItems.enumerated()), id: \.offset) { index, item in
                                let phrase = store.historyPhrase(for: item)
                                let isPhrase = item.count > 1
                                let isActive = item == activeMemoryItem || index == store.rootBreadcrumbIndex
                                Button {
                                    store.activateBreadcrumbCharacter(item)
                                } label: {
                                    Text(item)
                                        .font(.system(size: isPhrase ? 15 : 19, weight: .bold))
                                        .lineLimit(1)
                                        .truncationMode(.tail)
                                        .frame(maxWidth: isPhrase ? 132 : 28, alignment: .center)
                                        .padding(.horizontal, isPhrase ? 10 : 8)
                                        .frame(height: 32)
                                        .radixSurface(isActive ? RadixAccent.primary.opacity(0.18) : RadixTheme.secondaryBackground.opacity(0.72))
                                        .contentShape(RoundedRectangle(cornerRadius: 8))
                                }
                                .buttonStyle(.plain)
                                .modifier(BreadcrumbContextMenu(item: item, phrase: phrase))
                            }
                        }
                        .padding(.trailing, 8)
                        .padding(.vertical, 3)
                    }
                }
                if isAddingFromClipboard {
                    Label("Adding from clipboard…", systemImage: "clock")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .padding(.leading, 8)
                }
            }
            .padding(.leading, 8)
            .background(RadixTheme.background)
            .alert("No Study Items Found", isPresented: $showsEmptyClipboardAlert) {
                Button("OK", role: .cancel) { }
            } message: {
                Text("Copy Chinese text, then tap the clipboard button. Radix checks the first 8 Chinese characters for known phrases and characters.")
            }
        }
    }

    private var shouldShowStrip: Bool {
        HistoryStripDisplayPolicy.shouldShow(
            route: store.route,
            homeTab: store.homeTab,
            hasItems: !store.rootBreadcrumb.isEmpty,
            hasCaptureButton: true
        )
    }

    private func addFromClipboard() {
        guard !isAddingFromClipboard else { return }
        isAddingFromClipboard = true
        Task { @MainActor in
            await Task.yield()
            showsEmptyClipboardAlert = store.addClipboardStudyItemsToMemoryStrip(force: true) == 0
            isAddingFromClipboard = false
        }
    }
}

private struct BreadcrumbContextMenu: ViewModifier {
    let item: String
    let phrase: PhraseItem?
    @EnvironmentObject private var store: RadixStore

    func body(content: Content) -> some View {
        if let phrase {
            content.phraseContextMenu(phrase)
        } else {
            content.copyCharacterContextMenu(item, pinyin: store.item(for: item)?.pinyinText)
        }
    }
}
