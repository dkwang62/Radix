import SwiftUI

struct BreadcrumbStrip: View {
    @EnvironmentObject private var store: RadixStore

    private var activeCharacter: String? {
        if store.route == .search && store.homeTab == .dataEdit {
            let editingCharacter = store.dataEditCharacter.trimmingCharacters(in: .whitespacesAndNewlines)
            if !editingCharacter.isEmpty {
                return editingCharacter
            }
        }
        return store.previewCharacter ?? store.selectedCharacter
    }

    var body: some View {
        if !store.rootBreadcrumb.isEmpty {
            HStack(spacing: 6) {
                Text("Remembered")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .accessibilityLabel("Remembered characters")

                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(store.rootBreadcrumb.enumerated()), id: \.offset) { index, character in
                            let isActive = character == activeCharacter || index == store.rootBreadcrumbIndex
                            Button {
                                store.activateBreadcrumbCharacter(character)
                            } label: {
                                Text(character)
                                    .font(.system(size: 22, weight: .bold))
                                    .padding(.horizontal, 10)
                                    .padding(.vertical, 6)
                                    .background(isActive ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            .buttonStyle(.plain)
                            .copyCharacterContextMenu(character, pinyin: store.item(for: character)?.pinyinText)
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

