import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct DataChangedDictionarySection: View {
    @EnvironmentObject private var store: RadixStore

    @Binding var searchText: String
    let onPreviewCharacter: (String) -> Void

    var body: some View {
        let totalChangedCount = store.changedDictionaryCharacters.count

        return VStack(alignment: .leading, spacing: 16) {
            Text("Changed Characters")
                .font(ResponsiveFont.subheadline.bold())

            Text("Saved character changes are grouped here. Added characters can be deleted. Edited built-in characters can be reverted.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            if totalChangedCount == 0 {
                Text("No dictionary changes yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                TextField("Search changed characters", text: $searchText)
                    .font(ResponsiveFont.body)
                    .textFieldStyle(.roundedBorder)

                if !displayedAddedDictionaryCharacters.isEmpty {
                    changedCharacterGroup(
                        title: "Added (\(filteredAddedDictionaryCharacters.count))",
                        characters: displayedAddedDictionaryCharacters,
                        badge: "Added"
                    )
                }

                if !displayedEditedDictionaryCharacters.isEmpty {
                    changedCharacterGroup(
                        title: "Notes Added (\(filteredEditedDictionaryCharacters.count))",
                        characters: displayedEditedDictionaryCharacters,
                        badge: "Notes Added"
                    )
                }

                if filteredAddedDictionaryCharacters.count > displayedAddedDictionaryCharacters.count ||
                    filteredEditedDictionaryCharacters.count > displayedEditedDictionaryCharacters.count {
                    Text("Showing the first 80 results. Refine your search to narrow the list.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    private func changedCharacterGroup(title: String, characters: [String], badge: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            ForEach(characters, id: \.self) { character in
                let item = store.item(for: character)
                editableCharacterCard(character, badge: badge, item: item)
            }
        }
    }

    private var filteredAddedDictionaryCharacters: [String] {
        filterChangedDictionaryCharacters(store.addedDictionaryCharacters)
    }

    private var filteredEditedDictionaryCharacters: [String] {
        filterChangedDictionaryCharacters(store.editedDictionaryCharacters)
    }

    private var displayedAddedDictionaryCharacters: [String] {
        cappedChangedDictionaryCharacters(filteredAddedDictionaryCharacters)
    }

    private var displayedEditedDictionaryCharacters: [String] {
        cappedChangedDictionaryCharacters(filteredEditedDictionaryCharacters)
    }

    private func filterChangedDictionaryCharacters(_ characters: [String]) -> [String] {
        let query = searchText.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        guard !query.isEmpty else { return characters }
        return characters.filter { character in
            if character.lowercased().contains(query) {
                return true
            }
            guard let item = store.item(for: character) else { return false }
            return item.pinyinText.lowercased().contains(query) || item.definition.lowercased().contains(query)
        }
    }

    private func cappedChangedDictionaryCharacters(_ characters: [String]) -> [String] {
        Array(characters.prefix(80))
    }

    private func editableCharacterCard(_ character: String, badge: String, item: ComponentItem?) -> some View {
        let isBuiltInCharacter = store.editedDictionaryCharactersSet.contains(character)
        let pinyin = item?.pinyinText ?? ""
        let definition = item?.definition ?? ""

        return VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(character)
                    .font(ResponsiveFont.headline)
                    .copyTextContextMenu(
                        character,
                        buttonTitle: "Copy \"\(character)\"",
                        secondaryText: pinyin,
                        secondaryButtonTitle: pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? nil : "Copy \"\(pinyin.trimmingCharacters(in: .whitespacesAndNewlines))\""
                    )
                Spacer()
                Text(badge)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Button(store.characterNotesActionTitle(for: character)) {
                    store.openQuickCharacterEditor(character)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)

                Button(role: isBuiltInCharacter ? nil : .destructive) {
                    if isBuiltInCharacter {
                        store.restoreDictionaryCharacterFromLibrary(character)
                    } else {
                        store.loadDataEditEntry(for: character)
                        do {
                            try store.deleteCurrentDataEditEntry()
                        } catch {}
                    }
                } label: {
                    Text(isBuiltInCharacter ? "Revert" : "Delete")
                        .font(ResponsiveFont.caption)
                }
                .buttonStyle(.bordered)
                .controlSize(.mini)
            }

            if !pinyin.isEmpty {
                Text(pinyin)
                    .font(ResponsiveFont.body.monospaced())
            }

            if !definition.isEmpty {
                Text(definition)
                    .font(ResponsiveFont.body)
            }
        }
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .contentShape(Rectangle())
        .simultaneousGesture(TapGesture().onEnded {
            onPreviewCharacter(character)
        })
    }
}
