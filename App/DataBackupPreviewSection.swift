import SwiftUI

struct DataBackupPreviewSection: View {
    @EnvironmentObject var store: RadixStore
    @State var selectedPhrase: PhraseItem?
    @State var addedPhraseReviewCycle = PhraseReviewStatusCycleState()
    @State var revertBasePhraseMessage: String?

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
                colors: [Color.accentColor.opacity(0.10), RadixTheme.secondaryBackground.opacity(0.55)],
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
                .foregroundStyle(Color.accentColor)
                .frame(width: 42, height: 42)
                .background(Color.accentColor.opacity(0.14))
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

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
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
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
                backupStatisticRowContent(
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
            backupStatisticRowContent(
                title: title,
                value: value,
                subtitle: subtitle,
                systemName: systemName,
                tint: tint,
                showsChevron: false
            )
        }
    }

    func backupStatisticRowContent(
        title: String,
        value: String,
        subtitle: String,
        systemName: String,
        tint: Color,
        showsChevron: Bool
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: systemName)
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

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

            Text(value)
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(tint)

            if showsChevron {
                Image(systemName: "chevron.right")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
        .accessibilityElement(children: .combine)
    }

    var savedPagesNavigationRow: some View {
        Button {
            onOpenSavedPages?()
        } label: {
            HStack(alignment: .center, spacing: 10) {
                Image(systemName: "photo.on.rectangle")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 26, height: 26)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 7))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Saved Pages (\(store.allCollections.count))")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.primary)
                    if !RadixPlatform.isPhone {
                        Text("Open and manage pages in Browse.")
                            .font(ResponsiveFont.caption2)
                            .foregroundStyle(.secondary)
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: "chevron.right")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(onOpenSavedPages == nil)
    }
}
