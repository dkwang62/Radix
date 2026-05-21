import SwiftUI

struct DataBackupPreviewSection: View {
    @EnvironmentObject var store: RadixStore
    @State var selectedPhrase: PhraseItem?
    @State var addedPhraseReviewCycle = PhraseReviewStatusCycleState()
    @State var revertBasePhraseMessage: String?

    let addedPhraseEntries: [PhraseItem]
    let basePhraseCoreEditEntries: [PhraseItem]
    let phraseEntriesWithNotes: [PhraseItem]
    var title: String = "What Goes With the File"
    var subtitle: String = "This is the Radix work that can travel to another device."
    var addedPhraseReviewCount: Int = 0
    var addedPhrasePageCharacterCount: Int = 0
    var onReviewAddedPhrases: (() -> Void)?
    var onCreateAddedPhrasesPage: (() -> Void)?
    var onDeleteAddedPhrases: (() -> Void)?
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
                addedPhraseManagementRow
                addedPhraseReviewRows(addedPhraseEntries)
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

    var addedPhraseManagementRow: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "checklist")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Review Added Phrases")
                        .font(ResponsiveFont.caption.weight(.semibold))
                    Text(addedPhraseManagementText)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                    PhraseReviewStatusCycleHint()
                        .padding(.top, 2)
                }
            }

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 8) {
                    addedPhraseManagementButtons
                }
                VStack(alignment: .leading, spacing: 8) {
                    addedPhraseManagementButtons
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var addedPhraseManagementButtons: some View {
        Button {
            onReviewAddedPhrases?()
        } label: {
            Label("Classify & Prune", systemImage: "checklist")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(addedPhraseReviewCount == 0)

        Button {
            onCreateAddedPhrasesPage?()
        } label: {
            Label("Make AI Text Page", systemImage: "doc.text.magnifyingglass")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .buttonStyle(.borderedProminent)
        .controlSize(.small)
        .disabled(addedPhrasePageCharacterCount == 0)

        Button(role: .destructive) {
            onDeleteAddedPhrases?()
        } label: {
            Label("Delete Added", systemImage: RadixIcon.delete)
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(addedPhraseEntries.isEmpty)
    }

    var addedPhraseManagementText: String {
        if addedPhraseEntries.isEmpty {
            return "Add phrases first, then review which ones belong in Memory."
        }
        return "\(addedPhraseEntries.count) phrases in Memory. Check good phrases while reviewing, then complete checked phrases when you are done with them."
    }
}
