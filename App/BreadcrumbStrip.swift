import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

struct BreadcrumbStrip: View {
    @EnvironmentObject private var store: RadixStore

    private var memoryLabel: String {
        return "🕘"
    }

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
        if !store.rootBreadcrumb.isEmpty {
            HStack(spacing: 6) {
                Text(memoryLabel)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Memory items")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(store.rootBreadcrumb.enumerated()), id: \.offset) { index, item in
                            let phrase = store.mergedPhrase(for: item)
                            let isPhrase = phrase != nil && item.count > 1
                            let isActive = item == activeMemoryItem || index == store.rootBreadcrumbIndex
                            Button {
                                store.activateBreadcrumbCharacter(item)
                            } label: {
                                Text(item)
                                    .font(.system(size: isPhrase ? 16 : 22, weight: .bold))
                                    .lineLimit(1)
                                    .padding(.horizontal, isPhrase ? 12 : 10)
                                    .padding(.vertical, 6)
                                    .background(isActive ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .modifier(BreadcrumbContextMenu(item: item, phrase: phrase))
                        }
                    }
                    .padding(.trailing, 8)
                    .padding(.vertical, 4)
                }
            }
            .padding(.leading, 8)
            .background(Color(.systemBackground))
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
