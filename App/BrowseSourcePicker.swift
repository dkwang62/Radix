import SwiftUI

extension FilterGridTab {
    var browseSourceOptions: some View {
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
                title: "Create from Paste",
                subtitle: pastePageActionSubtitle("Paste Chinese text"),
                systemImage: "doc.on.clipboard",
                isLocked: !hasUnlimitedFreePages && freePagesRemaining == 0
            ) {
                beginManualCollection()
            }

            if !store.allCollections.isEmpty {
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.sortedCollections(order: browsePageSortOrder)) { collection in
                            sourceCollectionRow(collection)
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

    var browseSavedPageOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceActionButton(
                title: "Create from Paste",
                subtitle: pastePageActionSubtitle("Paste Chinese text and save it as a page"),
                systemImage: "doc.on.clipboard",
                isLocked: !hasUnlimitedFreePages && freePagesRemaining == 0
            ) {
                beginManualCollection()
            }

            if store.allCollections.isEmpty {
                ContentUnavailableView(
                    "No Pages",
                    systemImage: "photo.on.rectangle.angled",
                    description: Text("Scan or paste Chinese text.")
                )
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
            } else {
                pageSortControl(selection: Binding(
                    get: { browsePageSortOrder },
                    set: { updateBrowsePageSortOrder($0) }
                ))

                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 6) {
                        ForEach(store.sortedCollections(order: browsePageSortOrder)) { collection in
                            sourceCollectionRow(collection)
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

    func updateBrowsePageSortOrder(_ order: PageCollectionSortOrder) {
        browsePageSortOrder = order
        RadixBrowsePreferences.pageSortOrder = order
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

    func pastePageActionSubtitle(_ unlockedText: String) -> String {
        if hasUnlimitedFreePages {
            return unlockedText
        }
        if freePagesRemaining > 0 {
            return "\(freePagesRemaining) free pages left"
        }
        return "Radix Plus"
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

    func sourceCollectionRow(_ collection: CharacterCollection) -> some View {
        let isSelected = store.selectedBrowseCollectionID == collection.id
        return SourceCollectionRow(
            collection: collection,
            isSelected: isSelected,
            thumbnail: RadixThumbnail(jpegData: collection.thumbnailJPEGData),
            dateMode: browsePageSortOrder
        ) {
            store.selectBrowseCollection(id: collection.id)
            withAnimation {
                showBrowseSource = false
            }
        } onDelete: {
            pendingDeleteCollection = collection
        }
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

    func pageSortControl(selection: Binding<PageCollectionSortOrder>) -> some View {
        Picker("Page order", selection: selection) {
            ForEach(PageCollectionSortOrder.allCases) { order in
                Text(order.rawValue).tag(order)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .accessibilityLabel("Page order")
    }
}
