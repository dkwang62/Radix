import SwiftUI

struct DataBackupPreviewSection: View {
    @EnvironmentObject var store: RadixStore
    @State var selectedPhrase: PhraseItem?
    @State var revertBasePhraseMessage: String?

    let addedPhraseEntries: [PhraseItem]
    let basePhraseCoreEditEntries: [PhraseItem]
    let phraseEntriesWithNotes: [PhraseItem]
    var title: String = "What Goes With the File"
    var subtitle: String = "This is the Radix work that can travel to another device."
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
            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ResponsiveFont.headline)
                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

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
            DisclosureGroup("Saved Pages (\(store.allCollections.count))", isExpanded: $showSavedPagesPreview) {
                backupSavedPagesRows
            }

            DisclosureGroup("Favorites (\(store.favoriteItems.count) characters, \(store.favoritePhrasesItems.count) phrases)", isExpanded: $showFavoritesPreview) {
                backupFavoritesSummary
            }

            DisclosureGroup("AI Link Buttons (\(store.promptConfig.tasks.count))", isExpanded: $showAITemplatesPreview) {
                backupAITemplatesSummary
            }

            DisclosureGroup("App State & Settings", isExpanded: $showAppStatePreview) {
                backupAppStateSummary
            }

            DisclosureGroup("Characters You Added (\(store.addedDictionaryCharacters.count))", isExpanded: $showAddedCharactersPreview) {
                backupCharacterRows(store.addedDictionaryCharacters)
            }

            DisclosureGroup("Phrases You Added (\(addedPhraseEntries.count))", isExpanded: $showAddedPhrasesPreview) {
                backupPhraseRows(addedPhraseEntries)
            }

            DisclosureGroup("Characters You Changed (\(store.baseDictionaryCoreEditedCharacters.count))", isExpanded: $showEditedCharactersPreview) {
                backupCharacterRows(store.baseDictionaryCoreEditedCharacters)
            }

            DisclosureGroup("Phrases You Changed (\(basePhraseCoreEditEntries.count))", isExpanded: $showEditedPhrasesPreview) {
                revertBasePhrasesRow
                backupPhraseRows(basePhraseCoreEditEntries)
            }

            DisclosureGroup("Character Notes (\(store.dictionaryCharactersWithNotes.count))") {
                backupCharacterRows(store.dictionaryCharactersWithNotes)
            }

            DisclosureGroup("Phrase Notes (\(phraseEntriesWithNotes.count))") {
                backupPhraseRows(phraseEntriesWithNotes)
            }
        }
    }
}
