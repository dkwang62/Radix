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

                studyCheckpointsSection
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

    var studyCheckpointsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .firstTextBaseline) {
                Label("Checkpoints", systemImage: "clock.arrow.circlepath")
                    .font(ResponsiveFont.headline)
                Spacer()
                backupFilesLink
            }

            Text("Use this safety net after study sessions or before cleanup. Tap a checkpoint row below to return to that moment.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)

            checkpointActionRow

            latestCheckpointRows
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.52))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    var backupFilesLink: some View {
        Button(action: onOpenProtectRecover) {
            Label("Backup files", systemImage: "externaldrive")
                .font(ResponsiveFont.caption.weight(.semibold))
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .foregroundStyle(Color.accentColor)
    }

    var checkpointActionRow: some View {
        checkpointActionButton(
            title: isCreatingCheckpoint ? "Creating…" : RadixCopy.createCheckpoint,
            subtitle: "Save this moment",
            systemImage: "clock.badge.checkmark",
            tint: Color.accentColor,
            isLocked: entitlement.requiresPro(.datedCopies),
            action: {
                if entitlement.requiresPro(.datedCopies) {
                    onRequirePro(.datedCopies)
                } else {
                    onCreateCheckpoint()
                }
            }
        )
    }

    @ViewBuilder
    var latestCheckpointRows: some View {
        if checkpoints.isEmpty {
            Text("No checkpoints created yet.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(RadixTheme.background)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        } else {
            ScrollView(.vertical, showsIndicators: checkpoints.count > 3) {
                VStack(spacing: 6) {
                    ForEach(checkpoints) { checkpoint in
                        Button {
                            pendingCheckpointReturn = checkpoint
                        } label: {
                            checkpointListRow(checkpoint)
                        }
                        .buttonStyle(.plain)
                        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
                    }
                }
            }
            .frame(maxHeight: checkpointListMaxHeight)
        }
    }

    func checkpointListRow(_ checkpoint: LocalDataSnapshot) -> some View {
        HStack(spacing: 8) {
            Image(systemName: "clock.arrow.circlepath")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 24, height: 24)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 1) {
                Text(checkpoint.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .lineLimit(1)
                Text("\(checkpoint.relativeSavedText) · \(checkpoint.subtitle)")
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer(minLength: 0)

            Image(systemName: "arrow.counterclockwise")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func checkpointActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isLocked: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            checkpointActionButtonContent(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                tint: tint,
                isLocked: isLocked
            )
        }
        .buttonStyle(.plain)
        .disabled(isCreatingCheckpoint || isReturningToCheckpoint)
    }

    func checkpointActionButtonContent(
        title: String,
        subtitle: String,
        systemImage: String,
        tint: Color,
        isLocked: Bool
    ) -> some View {
        HStack(spacing: 8) {
            Image(systemName: isLocked ? "lock.fill" : systemImage)
                .font(.system(size: 15, weight: .bold))
                .foregroundStyle(tint)
                .frame(width: 28, height: 28)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(ResponsiveFont.caption.bold())
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
                Text(subtitle)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .layoutPriority(1)

            Spacer(minLength: 0)
        }
        .padding(8)
        .frame(maxWidth: .infinity, minHeight: 48, alignment: .leading)
        .background(tint.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 9))
        .overlay(
            RoundedRectangle(cornerRadius: 9)
                .stroke(tint.opacity(0.25), lineWidth: 1)
        )
    }

    var checkpointListMaxHeight: CGFloat {
        162
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
