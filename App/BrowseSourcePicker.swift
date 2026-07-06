import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

extension FilterGridTab {
    var browseSavedPageOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceOptionButton(
                title: "Dictionary",
                subtitle: "Full dictionary",
                isSelected: store.selectedBrowseCollection == nil,
                systemImage: "book"
            ) {
                store.selectBrowseCollection(id: nil)
            }

            sourceActionButton(
                title: "Text from Clipboard",
                subtitle: clipboardTextPageActionSubtitle("Copy Chinese text first"),
                systemImage: "doc.on.clipboard",
                isLocked: !hasUnlimitedFreePages && freePagesRemaining == 0
            ) {
                beginManualCollection()
            }

            if isProcessingBrowseImageImport {
                SourceMenuRow(
                    title: "Reading image...",
                    subtitle: "Creating a saved page",
                    systemImage: "hourglass",
                    iconColor: .accentColor
                )
            } else {
                sourceActionButton(
                    title: "Image from Clipboard",
                    subtitle: clipboardImagePageActionSubtitle,
                    systemImage: "doc.on.clipboard",
                    isLocked: entitlement.requiresPro(.datedCopies)
                ) {
                    beginClipboardImageImport()
                }

                browseAlbumImportButton

                sourceActionButton(
                    title: fileImportTitle,
                    subtitle: fileImagePageActionSubtitle,
                    systemImage: "folder",
                    isLocked: entitlement.requiresPro(.datedCopies)
                ) {
                    beginBrowseImageFileImport()
                }
            }

            if let imageActionMessage {
                Text(imageActionMessage)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .radixPill(
                        horizontal: 10,
                        vertical: 6,
                        background: RadixTheme.secondaryBackground.opacity(0.45)
                    )
            }

            if store.allCollections.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Use clipboard text, import an image, or use Camera.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(browsePageRows, id: \.collection.id) { row in
                            sourceCollectionRow(row.collection, dateMode: row.dateMode)
                        }
                    }
                }
                .frame(
                    minHeight: browseSourceCollectionListMinHeight,
                    maxHeight: browseSourceCollectionListMaxHeight
                )
            }
        }
    }

    var browseSourceCollectionListMinHeight: CGFloat {
        if isPhoneBrowseLayout {
            return 220
        }

        return RadixPlatform.isDesktop ? 320 : 360
    }

    var browseSourceCollectionListMaxHeight: CGFloat {
        if isPhoneBrowseLayout {
            return 320
        }

        return RadixPlatform.isDesktop ? 460 : 520
    }

    var browsePageRows: [(collection: CharacterCollection, dateMode: PageCollectionSortOrder)] {
        let recentlyViewed = store.allCollections
            .sorted {
                let lhsDate = $0.lastViewedAt ?? $0.createdAt
                let rhsDate = $1.lastViewedAt ?? $1.createdAt
                if lhsDate != rhsDate { return lhsDate > rhsDate }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }
            .prefix(3)

        let recentIDs = Set(recentlyViewed.map(\.id))
        let scanned = store.allCollections
            .filter { !recentIDs.contains($0.id) }
            .sorted {
                if $0.createdAt != $1.createdAt { return $0.createdAt > $1.createdAt }
                return $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending
            }

        return recentlyViewed.map { ($0, .lastViewed) } + scanned.map { ($0, .scanned) }
    }

    func clipboardTextPageActionSubtitle(_ unlockedText: String) -> String {
        if hasUnlimitedFreePages {
            return unlockedText
        }
        if freePagesRemaining > 0 {
            return "Copy Chinese text first. \(freePagesRemaining) free pages left"
        }
        return "Radix Plus"
    }

    var clipboardImagePageActionSubtitle: String {
        entitlement.requiresPro(.datedCopies) ? "Radix Plus" : "Copy an image first"
    }

    var albumImagePageActionSubtitle: String {
        entitlement.requiresPro(.datedCopies) ? "Radix Plus" : "Choose a photo"
    }

    var fileImagePageActionSubtitle: String {
        entitlement.requiresPro(.datedCopies) ? "Radix Plus" : "Choose an image file"
    }

    var fileImportTitle: String {
        "Image from Files"
    }

    @ViewBuilder
    var browseAlbumImportButton: some View {
        if entitlement.requiresPro(.datedCopies) {
            sourceActionButton(
                title: "Image from Album",
                subtitle: "Radix Plus",
                systemImage: "photo.on.rectangle",
                isLocked: true
            ) {
                store.showPaywall(for: .datedCopies)
            }
        } else {
            BrowsePhotoImportSourceRow(
                subtitle: albumImagePageActionSubtitle,
                onImage: { image in
                    Task { await recognizeBrowseImage(image) }
                },
                onError: { error in
                    imageActionMessage = error.localizedDescription
                }
            )
        }
    }

    func sourceActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        isLocked: Bool = false,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            SourceMenuRow(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconColor: .accentColor,
                trailingSystemImage: isLocked ? "lock.fill" : "plus.circle.fill"
            )
        }
        .buttonStyle(.plain)
    }

    func sourceCollectionRow(
        _ collection: CharacterCollection,
        dateMode: PageCollectionSortOrder? = nil
    ) -> some View {
        let isSelected = store.selectedBrowseCollectionID == collection.id
        let matchingPracticeID = store.matchingConversationPracticeTopicID(forPageID: collection.id, title: collection.name)
        let openPractice: (() -> Void)? = matchingPracticeID.map { topicID in
            {
                store.openConversationPractice(topicID: topicID)
                withAnimation {
                    showBrowseSource = false
                }
            }
        }
        return SourceCollectionRow(
            collection: collection,
            isSelected: isSelected,
            thumbnail: RadixThumbnail(jpegData: collection.thumbnailJPEGData),
            dateMode: dateMode ?? .lastViewed,
            onSelect: {
                store.selectBrowseCollection(id: collection.id)
                withAnimation {
                    showBrowseSource = false
                }
            },
            onOpenPractice: openPractice
        )
    }

    func sourceOptionButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            withAnimation {
                showBrowseSource = false
            }
        } label: {
            SourceMenuRow(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                isSelected: isSelected,
                iconColor: isSelected ? .accentColor : .secondary,
                trailingSystemImage: isSelected ? "checkmark.circle.fill" : nil
            )
        }
        .buttonStyle(.plain)
    }
}

#if canImport(PhotosUI)
private struct BrowsePhotoImportSourceRow: View {
    @State private var selectedPhoto: PhotosPickerItem?
    let subtitle: String
    let onImage: @MainActor (CapturedImage) -> Void
    let onError: @MainActor (Error) -> Void

    var body: some View {
        PhotosPicker(selection: $selectedPhoto, matching: .images) {
            SourceMenuRow(
                title: "Image from Album",
                subtitle: subtitle,
                systemImage: "photo.on.rectangle",
                iconColor: .accentColor,
                trailingSystemImage: "plus.circle.fill"
            )
        }
        .buttonStyle(.plain)
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    let image = try await CaptureImageLoader.capturedImage(from: item)
                    await MainActor.run {
                        selectedPhoto = nil
                        onImage(image)
                    }
                } catch {
                    await MainActor.run {
                        selectedPhoto = nil
                        onError(error)
                    }
                }
            }
        }
    }
}
#else
private struct BrowsePhotoImportSourceRow: View {
    let subtitle: String
    let onImage: @MainActor (CapturedImage) -> Void
    let onError: @MainActor (Error) -> Void

    var body: some View {
        Button {
            onError(CocoaError(.featureUnsupported))
        } label: {
            SourceMenuRow(
                title: "Image from Album",
                subtitle: subtitle,
                systemImage: "photo.on.rectangle",
                iconColor: .accentColor,
                trailingSystemImage: "plus.circle.fill"
            )
        }
        .buttonStyle(.plain)
    }
}
#endif
