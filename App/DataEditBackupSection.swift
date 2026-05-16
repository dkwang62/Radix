import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

extension DataEditTab {
    var libraryOverviewSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            libraryHealthSummary
            personalLibraryTimelineSection
        }
    }

    var libraryPathCards: some View {
        LazyVGrid(columns: libraryPathColumns, spacing: 10) {
            DataEditPathCard(
                title: "My Data",
                subtitle: "Review your added characters, phrases, pages, notes, and favorites.",
                systemName: "books.vertical.fill",
                tint: .blue,
                badge: "Free",
                isLocked: false
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    activeDataEditSection = .library
                }
            }

            DataEditPathCard(
                title: "My Backup",
                subtitle: "Data portability for iPhone, iPad, and Mac.",
                systemName: "externaldrive.fill",
                tint: .accentColor,
                badge: entitlement.requiresPro(.myBackup) ? "$19" : "Unlocked",
                isLocked: entitlement.requiresPro(.myBackup)
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    activeDataEditSection = .myBackup
                }
            }

            DataEditPathCard(
                title: "Advanced",
                subtitle: "Developer exports for reuse outside Radix.",
                systemName: "shippingbox.fill",
                tint: .orange,
                badge: entitlement.requiresPro(.advanced) ? "$99" : "Unlocked",
                isLocked: entitlement.requiresPro(.advanced)
            ) {
                withAnimation(.easeInOut(duration: 0.18)) {
                    activeDataEditSection = .advanced
                }
            }
        }
    }

    var backupAndRestoreSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text("Move Between Devices")
                    .font(ResponsiveFont.headline)
                Text("$19")
                    .font(ResponsiveFont.caption.bold())
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.accentColor.opacity(0.14))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Text("Move the work you did on one device to your other devices.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            myBackupVisibilityNote

            LazyVGrid(columns: backupActionColumns, spacing: 10) {
                Button {
                    guard !entitlement.requiresPro(.myBackup) else {
                        onRequirePro(.myBackup)
                        return
                    }
                    createPortableBackup()
                } label: {
                    DataBackupActionButton(
                        title: reuseExportInProgress && reuseExportFilename.contains("backup") ? "Preparing..." : "Export My Data",
                        subtitle: "For another device",
                        systemName: "square.and.arrow.up.fill",
                        foreground: .white,
                        background: Color.accentColor,
                        border: Color.accentColor,
                        isLocked: entitlement.requiresPro(.myBackup)
                    )
                }
                .buttonStyle(.plain)
                .disabled(reuseExportInProgress)

                Button {
                    guard !entitlement.requiresPro(.myBackup) else {
                        onRequirePro(.myBackup)
                        return
                    }
                    pendingRestoreMode = .additive
                    showRestorePicker = true
                } label: {
                    DataBackupActionButton(
                        title: "Import and Add",
                        subtitle: "Keep this device's data",
                        systemName: "square.and.arrow.down",
                        foreground: Color.accentColor,
                        background: Color.accentColor.opacity(0.1),
                        border: Color.accentColor.opacity(0.35),
                        isLocked: entitlement.requiresPro(.myBackup)
                    )
                }
                .buttonStyle(.plain)

                Button {
                    guard !entitlement.requiresPro(.myBackup) else {
                        onRequirePro(.myBackup)
                        return
                    }
                    pendingRestoreMode = .complete
                    showRestorePicker = true
                } label: {
                    DataBackupActionButton(
                        title: "Import and Replace",
                        subtitle: "Use another device's data",
                        systemName: "square.and.arrow.down.fill",
                        foreground: Color.orange,
                        background: Color.orange.opacity(0.1),
                        border: Color.orange.opacity(0.35),
                        isLocked: entitlement.requiresPro(.myBackup)
                    )
                }
                .buttonStyle(.plain)
            }

            whatsInMyBackupSection
        }
        .padding()
        .background(Color(.secondarySystemBackground).opacity(0.4))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    var myBackupVisibilityNote: some View {
        if entitlement.requiresPro(.myBackup) {
            Label("Preview is free. Exporting and importing unlock with My Backup.", systemImage: "lock.open")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var libraryHealthSummary: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Saved In Radix", systemImage: "tray.full.fill")
                    .font(ResponsiveFont.headline)
                Spacer()
                Text("\(libraryProtectedItemCount) items")
                    .font(ResponsiveFont.caption.bold())
                    .foregroundStyle(.secondary)
            }

            LazyVGrid(columns: librarySummaryColumns, spacing: 8) {
                librarySummaryTile(
                    title: "Characters",
                    value: "\(store.addedDictionaryCharacters.count + store.baseDictionaryCoreEditedCharacters.count + store.dictionaryCharactersWithNotes.count)",
                    systemImage: "character.book.closed",
                    tint: .blue
                )
                librarySummaryTile(
                    title: "Phrases",
                    value: "\(addedPhraseEntries.count + basePhraseCoreEditEntries.count + phraseEntriesWithNotes.count)",
                    systemImage: "text.quote",
                    tint: .green
                )
                librarySummaryTile(
                    title: "Pages",
                    value: "\(store.allCollections.count)",
                    systemImage: "photo.on.rectangle",
                    tint: .purple
                )
                librarySummaryTile(
                    title: "Study",
                    value: "\(store.favoriteItems.count + store.favoritePhrasesItems.count + store.rootBreadcrumb.count)",
                    systemImage: "star.fill",
                    tint: .orange
                )
            }
        }
        .padding(12)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var libraryProtectedItemCount: Int {
        store.addedDictionaryCharacters.count
            + store.baseDictionaryCoreEditedCharacters.count
            + store.dictionaryCharactersWithNotes.count
            + addedPhraseEntries.count
            + basePhraseCoreEditEntries.count
            + phraseEntriesWithNotes.count
            + store.allCollections.count
            + store.favoriteItems.count
            + store.favoritePhrasesItems.count
            + store.rootBreadcrumb.count
    }

    var personalLibraryTimelineSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Label("Recent Saved Items", systemImage: "clock.arrow.circlepath")
                    .font(ResponsiveFont.headline)
                Spacer()
                Text("Tap to open")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 8) {
                let moments = personalLibraryMoments
                if moments.isEmpty {
                    DataLibraryMomentRow(
                        title: "Your Radix library starts here",
                        subtitle: "Scan a page, save a phrase, favorite a character, or add your own notes.",
                        detail: nil,
                        systemName: "sparkles",
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
                subtitle: "\(collection.characters.count) characters from a saved page",
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
                subtitle: phrase.meanings.isEmpty ? "Added phrase" : phrase.meanings,
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
                subtitle: item?.pinyinText.isEmpty == false ? item?.pinyinText ?? "Added character" : "Added character",
                detail: "My Data",
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

    var librarySummaryColumns: [GridItem] {
        if sizeClass == .compact {
            return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 2)
        }
        return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 4)
    }

    var libraryPathColumns: [GridItem] {
        if sizeClass == .compact {
            return [GridItem(.flexible(minimum: 220), spacing: 10)]
        }
        return Array(repeating: GridItem(.flexible(minimum: 190), spacing: 10), count: 3)
    }

    var backupActionColumns: [GridItem] {
        if sizeClass == .compact {
            return [GridItem(.flexible(minimum: 220), spacing: 10)]
        }
        return Array(repeating: GridItem(.flexible(minimum: 150), spacing: 10), count: 3)
    }

    func librarySummaryTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 20, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var whatsInMyBackupSection: some View {
        DataBackupPreviewSection(
            addedPhraseEntries: addedPhraseEntries,
            basePhraseCoreEditEntries: basePhraseCoreEditEntries,
            phraseEntriesWithNotes: phraseEntriesWithNotes,
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

    func createPortableBackup() {
        guard !entitlement.requiresPro(.myBackup) else {
            onRequirePro(.myBackup)
            return
        }
        reuseExportInProgress = true
        reuseExportMessage = nil
        Task { @MainActor in
            do {
                let data = try dataExportService.exportPortableBackup(store.portableBackupPackage())
                reuseExportDocument = BinaryFileDocument(data: data)
                reuseExportFilename = "radix_unified_backup"
                reuseExportContentType = .json
                reuseExportInProgress = false
                showReuseExporter = true
            } catch {
                reuseExportInProgress = false
                backupError = error.localizedDescription
                showBackupAlert = true
            }
        }
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
