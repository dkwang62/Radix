import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
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
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: RadixIcon.help)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 26, height: 26)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 3) {
                Text("Choose what deserves more study.")
                    .font(ResponsiveFont.body.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)
                Text("Review recent items, favorite the useful ones, then clear Recent.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            Spacer(minLength: 8)

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
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.72))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var studyDashboardSummary: some View {
        LazyVGrid(columns: studySummaryColumns, spacing: 6) {
            studySummaryTile(
                title: "Recent",
                value: "\(store.recentCharacterCount)",
                systemImage: "clock",
                tint: .blue
            )
            studySummaryTile(
                title: "Characters",
                value: "\(store.favoriteItems.count)",
                systemImage: RadixIcon.saved,
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
        .padding(.top, 2)
    }

    var studySummaryColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return [GridItem(.adaptive(minimum: 136), spacing: 6)]
        #else
        return [GridItem(.adaptive(minimum: isNarrowStudyLayout ? 132 : 136), spacing: 6)]
        #endif
    }

    func studySummaryTile(title: String, value: String, systemImage: String, tint: Color) -> some View {
        HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            Text("\(value) \(title)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: 34, alignment: .leading)
        .background(Color(.secondarySystemBackground).opacity(0.48))
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
