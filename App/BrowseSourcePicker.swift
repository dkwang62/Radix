import SwiftUI
import UIKit

extension FilterGridTab {
    var browsePageSortOrder: PageCollectionSortOrder {
        get { PageCollectionSortOrder(rawValue: browsePageSortRawValue) ?? .lastViewed }
        nonmutating set { browsePageSortRawValue = newValue.rawValue }
    }

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
                subtitle: "Paste Chinese text",
                systemImage: "doc.on.clipboard"
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
                subtitle: "Paste Chinese text and save it as a page",
                systemImage: "doc.on.clipboard"
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
                    set: { browsePageSortOrder = $0 }
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

    var browseSourceCollectionListMinHeight: CGFloat {
        if isPhoneBrowseLayout {
            return 220
        }

        #if targetEnvironment(macCatalyst)
        return 320
        #else
        return 360
        #endif
    }

    var browseSourceCollectionListMaxHeight: CGFloat {
        if isPhoneBrowseLayout {
            return 320
        }

        #if targetEnvironment(macCatalyst)
        return 460
        #else
        return 520
        #endif
    }

    func sourceActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
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
                trailingSystemImage: "plus.circle.fill"
            )
        }
        .buttonStyle(.plain)
    }

    func sourceCollectionRow(_ collection: CharacterCollection) -> some View {
        let isSelected = store.selectedBrowseCollectionID == collection.id
        return SourceCollectionRow(
            collection: collection,
            isSelected: isSelected,
            thumbnail: sourceThumbnailImage(for: collection),
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

    func sourceThumbnailImage(for collection: CharacterCollection) -> UIImage? {
        guard let data = collection.thumbnailJPEGData else { return nil }
        return UIImage(data: data)
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
