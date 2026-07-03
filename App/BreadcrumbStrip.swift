import SwiftUI

struct BreadcrumbStrip: View {
    @EnvironmentObject private var store: RadixStore
    @State private var showsHistoryHelp = false

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

    var body: some View {
        if shouldShowStrip {
            HStack(spacing: 6) {
                Button {
                    showsHistoryHelp.toggle()
                } label: {
                    Image(systemName: RadixGlossaryIcon.systemImage(for: RadixTerm.history))
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 32)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(RadixTerm.history)
                .help(RadixTerm.history)
                .popover(isPresented: $showsHistoryHelp, attachmentAnchor: .rect(.bounds), arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 6) {
                        RadixTermLabel(term: RadixTerm.history)
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                        Text("Recently inspected characters and phrases for fast exploration.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding()
                    .frame(maxWidth: 280, alignment: .leading)
                }

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 6) {
                        ForEach(Array(store.rootBreadcrumb.enumerated()), id: \.offset) { index, item in
                            let phrase = store.mergedPhrase(for: item)
                            let isPhrase = phrase != nil && item.count > 1
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
                                    .background(isActive ? Color.accentColor.opacity(0.18) : RadixTheme.secondaryBackground.opacity(0.72))
                                    .clipShape(RoundedRectangle(cornerRadius: 8))
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
            .padding(.leading, 8)
            .background(RadixTheme.background)
        }
    }

    private var shouldShowStrip: Bool {
        guard !store.rootBreadcrumb.isEmpty else { return false }

        switch store.route {
        case .search:
            switch store.homeTab {
            case .smart, .filter:
                return true
            case .favourites, .dataEdit:
                return false
            }
        case .lineage:
            return true
        case .capture, .favourites, .aiLink, .settings:
            return false
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
