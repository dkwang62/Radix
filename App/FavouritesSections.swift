import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                if !hasDismissedStudyIntro {
                    studyIntroCard
                }

                studyDashboardSummary

                if hasStudyGridItems {
                    recentStudySection
                }

                if !store.allCollections.isEmpty {
                    scannedPagesStudySection
                }
            }
            .padding(.horizontal)
            .padding(.bottom, 20)
        }
    }

    var studyIntroCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "sparkles")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 30, height: 30)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 4) {
                    Text("Choose what deserves more study.")
                        .font(ResponsiveFont.body.weight(.semibold))
                    Text("Review recent characters and phrases, star the ones worth keeping, then clear Recent when the session is done.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)

                Button {
                    withAnimation { hasDismissedStudyIntro = true }
                } label: {
                    Image(systemName: "xmark")
                        .frame(width: 28, height: 28)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.secondary)
                .accessibilityLabel("Hide Study help")
            }

            LazyVGrid(columns: studyIntroColumns, spacing: 8) {
                studyIntroPill("All", "Review recent and saved items")
                studyIntroPill("Saved", "Keep the smaller study set")
                studyIntroPill("Clear Recent", "Finish today’s session")
            }
        }
        .padding(12)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var studyIntroColumns: [GridItem] {
        [GridItem(.adaptive(minimum: 104), spacing: 8)]
    }

    func studyIntroPill(_ title: String, _ subtitle: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption.weight(.bold))
                .foregroundStyle(.primary)
            Text(subtitle)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var studyDashboardSummary: some View {
        LazyVGrid(columns: studySummaryColumns, spacing: 8) {
            studySummaryTile(
                title: "Recent",
                value: "\(store.recentCharacterCount)",
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
        return [GridItem(.adaptive(minimum: 112), spacing: 8)]
        #else
        return [GridItem(.adaptive(minimum: isNarrowStudyLayout ? 132 : 128), spacing: 8)]
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
