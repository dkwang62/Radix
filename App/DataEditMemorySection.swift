import SwiftUI

extension DataEditTab {
    var libraryOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            memoryContentsSection
            personalLibraryTimelineSection
        }
    }

    var memoryContentsSection: some View {
        DataBackupPreviewSection(
            addedPhraseEntries: addedPhraseEntries,
            basePhraseCoreEditEntries: basePhraseCoreEditEntries,
            phraseEntriesWithNotes: phraseEntriesWithNotes,
            title: "Memory",
            subtitle: "Everything you add, save, favorite, set up, or leave in progress in Radix. Dated copies and files for other devices both save this same Memory.",
            onPreviewCharacter: previewBackupCharacter,
            showSavedPagesPreview: $showSavedPagesPreview,
            showFavoritesPreview: $showFavoritesPreview,
            showAITemplatesPreview: $showAITemplatesPreview,
            showAppStatePreview: $showAppStatePreview,
            showAddedCharactersPreview: $showAddedCharactersPreview,
            showAddedPhrasesPreview: $showAddedPhrasesPreview,
            showEditedCharactersPreview: $showEditedCharactersPreview,
            showEditedPhrasesPreview: $showEditedPhrasesPreview
        )
    }

    var personalLibraryTimelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recent Saved Items", systemImage: "clock.arrow.circlepath")
                    .font(ResponsiveFont.headline)
                Spacer()
                Text("Open in Browse")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                let moments = personalLibraryMoments
                if moments.isEmpty {
                    DataLibraryMomentRow(
                        title: "Your Radix library starts here",
                        subtitle: "Scan a page, save a phrase, mark a favorite, or add your own notes.",
                        detail: nil,
                        systemName: "plus.circle",
                        tint: .accentColor
                    ) {
                        store.route = .capture
                    }
                } else {
                    ForEach(moments) { moment in
                        DataLibraryMomentRow(
                            title: moment.title,
                            subtitle: moment.subtitle,
                            detail: moment.detail,
                            systemName: moment.systemName,
                            tint: moment.tint
                        ) {
                            openPersonalLibraryMoment(moment)
                        }
                    }
                }
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var personalLibraryMoments: [DataLibraryMoment] {
        var moments: [DataLibraryMoment] = []

        moments += store.allCollections.prefix(3).map { collection in
            DataLibraryMoment(
                kind: .page(collection.id),
                title: store.collectionDisplayName(collection.name),
                subtitle: "\(collection.characters.count) characters in a saved page",
                detail: displayDate(collection.createdAt),
                systemName: collection.sourceType == .ocr ? "doc.text.viewfinder" : "doc.text",
                tint: .purple,
                sortDate: collection.createdAt
            )
        }

        moments += store.favoriteItems.prefix(3).map { item in
            let date = store.favoriteAddedDate(for: item.character)
            return DataLibraryMoment(
                kind: .character(item.character),
                title: item.character,
                subtitle: item.pinyinText.isEmpty ? "Favorite character" : item.pinyinText,
                detail: date.map(displayDate(_:)) ?? "Favorite",
                systemName: "star.fill",
                tint: .orange,
                sortDate: date ?? .distantPast
            )
        }

        moments += store.favoritePhrasesItems.prefix(3).map { phrase in
            DataLibraryMoment(
                kind: .phrase(phrase.word),
                title: phrase.word,
                subtitle: phrase.pinyin.isEmpty ? "Favorite phrase" : phrase.pinyin,
                detail: phrase.addedAt.map(displayDate(_:)) ?? "Phrase",
                systemName: "text.quote",
                tint: .green,
                sortDate: phrase.addedAt ?? .distantPast
            )
        }

        moments += addedPhraseEntries.prefix(3).map { phrase in
            DataLibraryMoment(
                kind: .phrase(phrase.word),
                title: phrase.word,
                subtitle: phrase.meanings.isEmpty ? "Phrase you added" : phrase.meanings,
                detail: phrase.addedAt.map(displayDate(_:)) ?? "Added",
                systemName: "plus.message.fill",
                tint: .blue,
                sortDate: phrase.addedAt ?? .distantPast
            )
        }

        moments += store.addedDictionaryCharacters.prefix(3).map { character in
            let item = store.item(for: character)
            return DataLibraryMoment(
                kind: .character(character),
                title: character,
                subtitle: item?.pinyinText.isEmpty == false ? item?.pinyinText ?? "Character you added" : "Character you added",
                detail: "Added",
                systemName: "character.book.closed.fill",
                tint: .cyan,
                sortDate: store.overlayAddedDates[character] ?? .distantPast
            )
        }

        return Array(moments.sorted {
            if $0.sortDate != $1.sortDate { return $0.sortDate > $1.sortDate }
            return $0.title < $1.title
        }.prefix(8))
    }

    func openPersonalLibraryMoment(_ moment: DataLibraryMoment) {
        switch moment.kind {
        case .page(let id):
            store.goToBrowse()
            store.selectBrowseCollection(id: id)
        case .character(let character):
            store.goToBrowse()
            store.preview(character: character)
        case .phrase(let word):
            if let phrase = store.mergedPhrase(for: word) {
                store.goToBrowse()
                store.presentPhraseInSidebar(phrase)
            }
        }
    }

    func displayDate(_ date: Date) -> String {
        date.formatted(date: .abbreviated, time: .omitted)
    }

    func previewBackupCharacter(_ character: String) {
        store.preview(character: character)
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            withAnimation { dataEditScrollProxy?.scrollTo("myDataTop", anchor: .top) }
        }
        #endif
    }
}

enum DataLibraryMomentKind: Hashable {
    case page(UUID)
    case character(String)
    case phrase(String)
}

struct DataLibraryMoment: Identifiable, Hashable {
    let kind: DataLibraryMomentKind
    let title: String
    let subtitle: String
    let detail: String?
    let systemName: String
    let tint: Color
    let sortDate: Date

    var id: String {
        switch kind {
        case .page(let id): return "page-\(id.uuidString)"
        case .character(let character): return "character-\(character)"
        case .phrase(let word): return "phrase-\(word)"
        }
    }
}

struct DataLibraryMomentRow: View {
    let title: String
    let subtitle: String
    let detail: String?
    let systemName: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 10) {
                Image(systemName: systemName)
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 34, height: 34)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                    Text(subtitle)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                if let detail {
                    Text(detail)
                        .font(ResponsiveFont.caption2.bold())
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
