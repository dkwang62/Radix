import SwiftUI

struct DataBackupPreviewSection: View {
    @EnvironmentObject var store: RadixStore
    @State var selectedPhrase: PhraseItem?
    @State var addedPhraseReviewCycle = PhraseReviewStatusCycleState()
    @State var revertBasePhraseMessage: String?
    @State var pendingBasePhraseRevertWords: [String] = []

    let addedPhraseEntries: [PhraseItem]
    let basePhraseCoreEditEntries: [PhraseItem]
    let phraseEntriesWithNotes: [PhraseItem]
    var title: String = "What Will Be Saved"
    var subtitle: String = "This is your current Memory."
    var badges: [String] = []
    var isCompactListOnly = false
    var onOpenSavedPages: (() -> Void)?
    var onOpenAddedPhrases: (() -> Void)?
    let onPreviewCharacter: (String) -> Void

    @Binding var showSavedPagesPreview: Bool
    @Binding var showFavoritesPreview: Bool
    @Binding var showAITemplatesPreview: Bool
    @Binding var showPracticePreview: Bool
    @Binding var showAppStatePreview: Bool
    @Binding var showAddedCharactersPreview: Bool
    @Binding var showEditedCharactersPreview: Bool
    @Binding var showEditedPhrasesPreview: Bool

    var body: some View {
        Group {
            if isCompactListOnly {
                compactBody
            } else {
                fullBody
            }
        }
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
        .alert("Revert Edited Phrases?", isPresented: Binding(
            get: { !pendingBasePhraseRevertWords.isEmpty },
            set: { if !$0 { pendingBasePhraseRevertWords = [] } }
        )) {
            Button("Cancel", role: .cancel) {
                pendingBasePhraseRevertWords = []
            }
            Button("Revert", role: .destructive) {
                confirmRevertBasePhraseEdits()
            }
        } message: {
            Text("Revert \(pendingBasePhraseRevertWords.count) edited base phrase\(pendingBasePhraseRevertWords.count == 1 ? "" : "s") shown here? Saved notes are protected. A safety copy is created first.")
        }
    }

    var fullBody: some View {
        VStack(alignment: .leading, spacing: 16) {
            saveSummaryHeader

            previewDisclosureList
                .radixCard(background: RadixTheme.background)
        }
        .padding(12)
        .background(
            LinearGradient(
                colors: [RadixAccent.primary.opacity(0.10), RadixTheme.secondaryBackground.opacity(0.55)],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
        )
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
    }

    var compactBody: some View {
        previewDisclosureList
    }

    var saveSummaryHeader: some View {
        HStack(alignment: .top, spacing: 12) {
            Image(systemName: "externaldrive.badge.checkmark")
                .font(.system(size: 22, weight: .semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(
                    size: 42,
                    background: RadixAccent.primary.opacity(0.14)
                )

            VStack(alignment: .leading, spacing: 8) {
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(ResponsiveFont.title3.weight(.semibold))
                    if RadixPlatform.isPhone {
                        RadixInlineHelpDisclosure(
                            title: "Backup contents",
                            message: subtitle,
                            systemImage: "externaldrive.badge.checkmark"
                        )
                    } else {
                        Text(subtitle)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                }

                if !badges.isEmpty {
                    ViewThatFits(in: .horizontal) {
                        HStack(spacing: 6) {
                            saveBadges
                        }
                        VStack(alignment: .leading, spacing: 6) {
                            saveBadges
                        }
                    }
                }
            }

            Spacer(minLength: 0)
        }
    }

    var saveBadges: some View {
        ForEach(badges, id: \.self) { badge in
            Text(badge)
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixPill(background: RadixAccent.primary.opacity(0.12))
        }
    }

    var previewDisclosureList: some View {
        VStack(alignment: .leading, spacing: 12) {
            savedPagesNavigationRow

            DisclosureGroup("Favorites (\(store.favoriteItems.count) characters, \(store.favoritePhrasesItems.count) phrases)", isExpanded: $showFavoritesPreview) {
                backupFavoritesSummary
            }

            DisclosureGroup("AI Link Buttons (\(store.promptConfig.tasks.count))", isExpanded: $showAITemplatesPreview) {
                backupAITemplatesSummary
            }

            DisclosureGroup("Practice", isExpanded: $showPracticePreview) {
                backupPracticeSummary
            }

            DisclosureGroup("App State & Settings", isExpanded: $showAppStatePreview) {
                backupAppStateSummary
            }

            DisclosureGroup("Characters You Added (\(store.addedDictionaryCharacters.count))", isExpanded: $showAddedCharactersPreview) {
                backupCharacterRows(store.addedDictionaryCharacters)
            }

            backupStatisticRow(
                title: "Phrases You Added",
                value: "\(addedPhraseEntries.count)",
                subtitle: "Stored in Memory. Review and prune these in Study.",
                systemName: "text.quote",
                tint: .green,
                action: onOpenAddedPhrases
            )

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

    @ViewBuilder
    func backupStatisticRow(
        title: String,
        value: String,
        subtitle: String,
        systemName: String,
        tint: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        if let action {
            Button(action: action) {
                backupPreviewNavigationRow(
                    title: title,
                    value: value,
                    subtitle: subtitle,
                    systemName: systemName,
                    tint: tint,
                    showsChevron: true
                )
            }
            .buttonStyle(.plain)
            .accessibilityHint("Opens Study added phrases")
        } else {
            backupPreviewNavigationRow(
                title: title,
                value: value,
                subtitle: subtitle,
                systemName: systemName,
                tint: tint,
                showsChevron: false
            )
        }
    }

    func backupPreviewNavigationRow(
        title: String,
        value: String? = nil,
        subtitle: String,
        systemName: String,
        tint: Color,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemName)
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(tint)
                .radixIconButtonSurface(
                    size: 26,
                    background: tint.opacity(0.12),
                    radius: RadixRadius.small
                )

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.primary)
                if !RadixPlatform.isPhone {
                    Text(subtitle)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer(minLength: 0)

            if let value {
                Text(value)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(tint)
            }

            if showsChevron {
                RadixCompactChevronLabel(
                    chevronSystemName: "chevron.right",
                    chevronFont: ResponsiveFont.caption.weight(.semibold),
                    chevronForegroundStyle: .secondary,
                    chevronOpacity: 1
                )
            }
        }
        .accessibilityElement(children: .combine)
    }

    var savedPagesNavigationRow: some View {
        Button {
            onOpenSavedPages?()
        } label: {
            backupPreviewNavigationRow(
                title: "Saved Pages",
                value: "\(store.allCollections.count)",
                subtitle: "Open and manage pages.",
                systemName: "photo.on.rectangle",
                tint: RadixAccent.primary,
                showsChevron: true
            )
        }
        .buttonStyle(.plain)
        .disabled(onOpenSavedPages == nil)
    }
}
