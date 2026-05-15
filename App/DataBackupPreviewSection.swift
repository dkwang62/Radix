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
            Text("Included for Portability")
                .font(ResponsiveFont.headline)

            previewDisclosureList
                .padding(12)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
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
            DisclosureGroup("Pages (\(store.allCollections.count))", isExpanded: $showSavedPagesPreview) {
                backupSavedPagesRows
            }

            DisclosureGroup("Study (\(store.favoriteItems.count) characters, \(store.favoritePhrasesItems.count) phrases)", isExpanded: $showFavoritesPreview) {
                backupFavoritesSummary
            }

            DisclosureGroup("AI Link Templates (\(store.promptConfig.tasks.count) items)", isExpanded: $showAITemplatesPreview) {
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

            DisclosureGroup("Edited Characters (\(store.baseDictionaryCoreEditedCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                backupCharacterRows(store.baseDictionaryCoreEditedCharacters)
            }

            DisclosureGroup("Edited Phrases (\(basePhraseCoreEditEntries.count))", isExpanded: $showEditedPhrasesPreview) {
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
