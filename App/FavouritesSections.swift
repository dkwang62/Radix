import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !hasDismissedStudyIntro {
                    studyIntroCard
                }

                studyDashboardSummary

                studyProtectionLink

                if hasStudyGridItems {
                    recentStudySection
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
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

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
        .radixCard(
            padding: RadixLayoutMetrics.compactCardPadding,
            background: RadixTheme.secondaryBackground.opacity(0.72)
        )
    }

    var studyDashboardSummary: some View {
        LazyVGrid(columns: studySummaryColumns, spacing: 6) {
            studySummaryTile(
                title: "Recent",
                value: "\(store.recentCharacterCount)",
                systemImage: "clock",
                tint: .blue,
                action: {
                    withAnimation {
                        studyGridScope = .all
                    }
                }
            )
            studySummaryTile(
                title: "Favorites",
                value: "\(store.favoriteItems.count + store.favoritePhrasesItems.count)",
                systemImage: RadixIcon.saved,
                tint: .yellow,
                action: {
                    withAnimation {
                        studyGridScope = .favorites
                    }
                }
            )
            studySummaryTile(
                title: "Added Phrases",
                value: "\(addedStudyPhraseEntries.count)",
                systemImage: "text.quote",
                tint: .green,
                action: {
                    presentAddedPhraseReview()
                }
            )
            studySummaryTile(
                title: RadixCopy.savedPages,
                value: "\(store.allCollections.count)",
                systemImage: "photo.on.rectangle",
                tint: .purple,
                action: {
                    store.goToBrowsePages(selectLatest: false, preservingOrigin: true)
                }
            )
        }
        .padding(.top, 2)
    }

    var studyProtectionLink: some View {
        Button(action: onOpenProtectRecover) {
            HStack(spacing: 10) {
                Image(systemName: "shield.lefthalf.filled")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Protect or Recover Study")
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                    Text("Compare checkpoints and portable backups in one place.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()
                Image(systemName: "chevron.right")
                    .foregroundStyle(.secondary)
            }
            .padding(10)
            .background(RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
    }

    var studySummaryColumns: [GridItem] {
        if RadixPlatform.interfaceIdiom == .tablet {
            return Array(repeating: GridItem(.flexible(minimum: 0), spacing: 6), count: 2)
        }
        let minimum: CGFloat = RadixPlatform.isDesktop ? 136 : (isNarrowStudyLayout ? 132 : 136)
        return [GridItem(.adaptive(minimum: minimum), spacing: 6)]
    }

    @ViewBuilder
    func studySummaryTile(
        title: String,
        value: String,
        systemImage: String,
        tint: Color,
        action: (() -> Void)? = nil
    ) -> some View {
        let content = HStack(spacing: 6) {
            Image(systemName: systemImage)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 20, height: 20)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: RadixRadius.small))

            Text("\(value) \(title)")
                .font(.system(size: 16, weight: .bold, design: .rounded))
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.75)

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 8)
        .frame(maxWidth: .infinity, minHeight: RadixControlMetrics.compactHeight, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.48))
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

        if let action {
            Button(action: action) {
                content
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Show \(title)")
        } else {
            content
        }
    }

    func sectionTitle(_ title: String) -> some View {
        Text(title)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(.secondary)
    }

    func collectionDisplayName(_ collection: CharacterCollection) -> String {
        let name = collection.name.trimmingCharacters(in: .whitespacesAndNewlines)
        return name.isEmpty ? RadixCopy.savedPage : name
    }
}
