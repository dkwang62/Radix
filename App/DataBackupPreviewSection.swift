import SwiftUI

struct DataBackupPreviewSection: View {
    @EnvironmentObject var store: RadixStore
    @State var selectedPhrase: PhraseItem?
    @State var revertBasePhraseMessage: String?

    let addedPhraseEntries: [PhraseItem]
    let basePhraseCoreEditEntries: [PhraseItem]
    let phraseEntriesWithNotes: [PhraseItem]
    let onPreviewCharacter: (String) -> Void

    @Binding var showSavedPagesPreview: Bool
    @Binding var showFavoritesPreview: Bool
    @Binding var showAITemplatesPreview: Bool
    @Binding var showAppStatePreview: Bool
    @Binding var showAddedCharactersPreview: Bool
    @Binding var showAddedPhrasesPreview: Bool
    @Binding var showEditedCharactersPreview: Bool
    @Binding var showEditedPhrasesPreview: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("What's In My Backup")
                .font(ResponsiveFont.headline)

            previewDisclosureList
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .sheet(item: phonePhraseSheetBinding) { phrase in
            NavigationStack {
                PhraseInfoCard(phrase: phrase, onDone: {
                    selectedPhrase = nil
                })
                    .environmentObject(store)
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }

    var previewDisclosureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            DisclosureGroup("Saved Images (\(store.allCollections.count))", isExpanded: $showSavedPagesPreview) {
                backupSavedPagesRows
            }

            DisclosureGroup("Favorites (\(store.favoriteItems.count) characters, \(store.favoritePhrasesItems.count) phrases)", isExpanded: $showFavoritesPreview) {
                backupFavoritesSummary
            }

            DisclosureGroup("AI Templates (\(store.promptConfig.tasks.count) tasks)", isExpanded: $showAITemplatesPreview) {
                backupAITemplatesSummary
            }

            DisclosureGroup("App State", isExpanded: $showAppStatePreview) {
                backupAppStateSummary
            }

            DisclosureGroup("Added Characters (\(store.addedDictionaryCharacters.count))", isExpanded: $showAddedCharactersPreview) {
                backupCharacterRows(store.addedDictionaryCharacters)
            }

            DisclosureGroup("Added Phrases (\(addedPhraseEntries.count))", isExpanded: $showAddedPhrasesPreview) {
                backupPhraseRows(addedPhraseEntries)
            }

            DisclosureGroup("Edits to Base Dictionary (\(store.baseDictionaryCoreEditedCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                backupCharacterRows(store.baseDictionaryCoreEditedCharacters)
            }

            DisclosureGroup("Edits to Base Phrases (\(basePhraseCoreEditEntries.count))", isExpanded: $showEditedPhrasesPreview) {
                revertBasePhrasesRow
                backupPhraseRows(basePhraseCoreEditEntries)
            }

            DisclosureGroup("Characters With Notes (\(store.dictionaryCharactersWithNotes.count))") {
                backupCharacterRows(store.dictionaryCharactersWithNotes)
            }

            DisclosureGroup("Phrases With Notes (\(phraseEntriesWithNotes.count))") {
                backupPhraseRows(phraseEntriesWithNotes)
            }
        }
    }
}
