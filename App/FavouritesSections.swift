import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                studyDashboardSummary

                if !store.rootBreadcrumb.isEmpty {
                    recentStudySection
                }

                if !store.allCollections.isEmpty {
                    scannedPagesStudySection
                }

                if !store.favoriteItems.isEmpty {
                    favoriteCharactersSection
                }

                if !store.favoritePhrasesItems.isEmpty {
                    favoritePhrasesSection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    var studyDashboardSummary: some View {
        LazyVGrid(columns: studySummaryColumns, spacing: 8) {
            studySummaryTile(
                title: "Recent",
                value: "\(store.rootBreadcrumb.count)",
                systemImage: "clock",
                tint: .blue
            )
            studySummaryTile(
                title: "Characters",
                value: "\(store.favoriteItems.count)",
                systemImage: "star.fill",
                tint: .yellow
            )
            studySummaryTile(
                title: "Phrases",
                value: "\(store.favoritePhrasesItems.count)",
                systemImage: "text.quote",
                tint: .green
            )
            studySummaryTile(
                title: "Pages",
                value: "\(store.allCollections.count)",
                systemImage: "photo.on.rectangle",
                tint: .purple
            )
        }
        .padding(.top, 4)
    }

    var studySummaryColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 112), spacing: 8), count: 4)
        #else
        if isPhone {
            return Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 2)
        }
        return Array(repeating: GridItem(.flexible(minimum: 128), spacing: 8), count: 4)
        #endif
    }

    func studySummaryTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 30, height: 30)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 22, weight: .bold, design: .rounded))
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 62, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var recentStudySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Recent")

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    ForEach(Array(store.rootBreadcrumb.prefix(18).enumerated()), id: \.offset) { _, item in
                        recentStudyButton(item)
                    }
                }
                .padding(.vertical, 2)
                .padding(.trailing, 8)
            }
        }
    }

    func recentStudyButton(_ item: String) -> some View {
        let phrase = store.mergedPhrase(for: item)
        let isPhrase = phrase != nil && item.count > 1

        return Button {
            store.activateBreadcrumbCharacter(item)
        } label: {
            VStack(spacing: 2) {
                Text(item)
                    .font(.system(size: isPhrase ? 18 : 30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                if isPhrase {
                    Text(phrase?.pinyin.isEmpty == false ? phrase?.pinyin ?? "" : "Phrase")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                } else {
                    Text(store.item(for: item)?.pinyinText.isEmpty == false ? store.item(for: item)?.pinyinText ?? "" : " ")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }
            }
            .frame(width: isPhrase ? 118 : 64, height: 64)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .modifier(RecentStudyContextMenu(item: item, phrase: phrase))
    }

    var scannedPagesStudySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Pages")
                Spacer()
                Button {
                    store.goToBrowse()
                } label: {
                    Label("Browse", systemImage: "square.grid.2x2")
                        .font(ResponsiveFont.caption.bold())
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }

            LazyVGrid(columns: scannedPageColumns, spacing: 8) {
                ForEach(Array(store.allCollections.prefix(isPhone ? 4 : 6))) { collection in
                    scannedPageStudyButton(collection)
                }
            }
        }
    }

    var scannedPageColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 150, maximum: 220), spacing: 8), count: 3)
        #else
        if isPhone {
            return Array(repeating: GridItem(.flexible(minimum: 140), spacing: 8), count: 2)
        }
        return Array(repeating: GridItem(.flexible(minimum: 150, maximum: 220), spacing: 8), count: 3)
        #endif
    }

    func scannedPageStudyButton(_ collection: CharacterCollection) -> some View {
        Button {
            store.goToBrowse()
            store.selectBrowseCollection(id: collection.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: collection.sourceType == .ocr ? "doc.text.viewfinder" : "doc.text")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Spacer(minLength: 0)
                    Text("\(collection.characters.count)")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                }

                Text(collectionDisplayName(collection))
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)

                Text(collection.characters.prefix(10).joined(separator: " "))
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(.secondary)
    }

    var favoriteCharactersSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Characters")

            LazyVGrid(columns: favoriteCharacterColumns, spacing: 8) {
                ForEach(store.favoriteItems, id: \.character) { item in
                    favoriteCharacterCell(item)
                }
            }
        }
    }

    var favoritePhrasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            sectionTitle("Phrases")

            LazyVGrid(columns: favoritePhraseColumns, spacing: 8) {
                ForEach(store.favoritePhrasesItems, id: \.word) { phrase in
                    Button {
                        presentPhrase(phrase)
                    } label: {
                        PhraseSummaryTile(phrase: phrase)
                    }
                    .buttonStyle(.plain)
                    .phraseContextMenu(phrase)
                }
            }
        }
    }

    func collectionDisplayName(_ collection: CharacterCollection) -> String {
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? "Scanned Page" : name
    }
}

private struct RecentStudyContextMenu: ViewModifier {
    let item: String
    let phrase: PhraseItem?
    @EnvironmentObject private var store: RadixStore

    func body(content: Content) -> some View {
        if let phrase {
            content.phraseContextMenu(phrase)
        } else {
            content.copyCharacterContextMenu(item, pinyin: store.item(for: item)?.pinyinText)
        }
    }
}
