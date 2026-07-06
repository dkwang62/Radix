import SwiftUI

extension DataEditTab {
    var compactBackupContentsSection: some View {
        DataBackupPreviewSection(
            addedPhraseEntries: addedPhraseEntries,
            basePhraseCoreEditEntries: basePhraseCoreEditEntries,
            phraseEntriesWithNotes: phraseEntriesWithNotes,
            title: RadixCopy.backupContents,
            subtitle: "Radix data included when you save or restore.",
            badges: ["Cross-Device", "Recoverable"],
            isCompactListOnly: true,
            onOpenSavedPages: {
                store.goToBrowsePages(selectLatest: false, preservingOrigin: true)
            },
            onOpenAddedPhrases: {
                store.goToStudyAddedPhrases()
            },
            onPreviewCharacter: previewBackupCharacter,
            showSavedPagesPreview: $showSavedPagesPreview,
            showFavoritesPreview: $showFavoritesPreview,
            showAITemplatesPreview: $showAITemplatesPreview,
            showPracticePreview: $showPracticePreview,
            showAppStatePreview: $showAppStatePreview,
            showAddedCharactersPreview: $showAddedCharactersPreview,
            showEditedCharactersPreview: $showEditedCharactersPreview,
            showEditedPhrasesPreview: $showEditedPhrasesPreview
        )
    }

    var compactBackupContentsDisclosure: some View {
        DisclosureGroup(isExpanded: $showBackupContentsDetails) {
            compactBackupContentsSection
                .padding(.top, 8)
        } label: {
            HStack(spacing: 8) {
                Label("What is included?", systemImage: "list.bullet.rectangle")
                    .font(ResponsiveFont.caption.weight(.semibold))
                Spacer(minLength: 0)
                Text("\(store.allCollections.count) pages, \(addedPhraseEntries.count) phrases")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(10)
        .radixSurface(RadixTheme.background)
    }

    func previewBackupCharacter(_ character: String) {
        store.preview(character: character)
        if RadixPlatform.isPhone {
            withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
        }
    }
}
