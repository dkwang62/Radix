import SwiftUI

extension FavouritesTab {
    var favouritesScrollContent: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 22) {
                if !hasDismissedStudyIntro {
                    studyIntroCard
                }

                studyDashboardSummary

                if !isPhone {
                    studySnapshotActions
                }

                if hasStudyGridItems {
                    recentStudySection
                }

            }
            .padding(.horizontal)
            .padding(.bottom, isPhone ? 92 : 20)
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
                title: "Saved Pages",
                value: "\(store.allCollections.count)",
                systemImage: "photo.on.rectangle",
                tint: .purple,
                action: {
                    store.goToBrowsePages(selectLatest: false)
                }
            )
        }
        .padding(.top, 2)
    }

    @ViewBuilder
    var studySnapshotActions: some View {
        if onSaveSnapshot != nil || onRestoreSnapshot != nil {
            let snapshotsLocked = entitlement.requiresPro(.datedCopies)

            HStack(spacing: 8) {
                Button {
                    if snapshotsLocked {
                        onRequirePro(.datedCopies)
                    } else {
                        onSaveSnapshot?()
                    }
                } label: {
                    studySnapshotActionLabel(
                        title: isSavingSnapshot ? "Saving..." : "Save Device Snapshot",
                        systemImage: snapshotsLocked ? "lock.fill" : (isSavingSnapshot ? "hourglass" : "tray.and.arrow.down"),
                        isPrimary: true,
                        lockBadge: snapshotsLocked ? "Plus" : nil
                    )
                }
                .buttonStyle(.plain)
                .disabled(isSavingSnapshot || isRestoringSnapshot)

                if snapshotsLocked {
                    Button {
                        onRequirePro(.datedCopies)
                    } label: {
                        studySnapshotActionLabel(
                            title: "Restore Device Snapshot",
                            systemImage: "lock.fill",
                            isPrimary: false,
                            lockBadge: "Plus"
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingSnapshot || isRestoringSnapshot)
                } else {
                    Menu {
                        if localSnapshots.isEmpty {
                            Text("No snapshots saved")
                        } else {
                            ForEach(localSnapshots) { snapshot in
                                Button {
                                    pendingSnapshotRestore = snapshot
                                } label: {
                                    Label(snapshot.title, systemImage: "clock.arrow.circlepath")
                                }
                            }
                        }

                        Divider()

                        Button {
                            onRefreshSnapshots?()
                        } label: {
                            Label("Refresh List", systemImage: "arrow.clockwise")
                        }
                    } label: {
                        studySnapshotActionLabel(
                            title: isRestoringSnapshot ? "Restoring..." : "Restore Device Snapshot",
                            systemImage: isRestoringSnapshot ? "hourglass" : "arrow.counterclockwise",
                            isPrimary: false,
                            lockBadge: nil
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(isSavingSnapshot || isRestoringSnapshot)
                }
            }
            .onAppear {
                onRefreshSnapshots?()
            }
        }
    }

    func studySnapshotActionLabel(
        title: String,
        systemImage: String,
        isPrimary: Bool,
        lockBadge: String?
    ) -> some View {
        HStack(spacing: 7) {
            Image(systemName: systemImage)
                .font(.system(size: 14, weight: .semibold))
            Text(title)
                .font(ResponsiveFont.caption.weight(.bold))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
            if let lockBadge {
                Text(lockBadge)
                    .font(ResponsiveFont.caption2.weight(.bold))
                    .foregroundStyle(.white)
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
                    .background(Color.accentColor)
                    .clipShape(Capsule())
                    .accessibilityHidden(true)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 40)
        .foregroundStyle(isPrimary ? Color.white : Color.accentColor)
        .background(isPrimary ? Color.accentColor : Color.accentColor.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
    }

    var studySummaryColumns: [GridItem] {
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
        return name.isEmpty ? "Saved Page" : name
    }
}
