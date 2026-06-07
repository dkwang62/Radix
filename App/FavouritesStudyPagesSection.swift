import SwiftUI

extension FavouritesTab {
    var scannedPagesStudySection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                sectionTitle("Pages")
                Spacer()
                pageSortControl(selection: Binding(
                    get: { studyPageSortOrder },
                    set: { studyPageSortOrder = $0 }
                ))
            }

            LazyVStack(alignment: .leading, spacing: 6) {
                ForEach(Array(store.sortedCollections(order: studyPageSortOrder).prefix(isNarrowStudyLayout ? 4 : 6))) { collection in
                    scannedPageStudyButton(collection)
                }
            }
        }
    }

    func scannedPageStudyButton(_ collection: CharacterCollection) -> some View {
        SourceCollectionRow(
            collection: collection,
            isSelected: store.selectedBrowseCollectionID == collection.id,
            thumbnail: RadixThumbnail(jpegData: collection.thumbnailJPEGData),
            dateMode: studyPageSortOrder
        ) {
            store.goToBrowse()
            store.selectBrowseCollection(id: collection.id)
        }
    }

    func pageSortControl(selection: Binding<PageCollectionSortOrder>) -> some View {
        Picker("Page order", selection: selection) {
            ForEach(PageCollectionSortOrder.allCases) { order in
                Text(order.rawValue).tag(order)
            }
        }
        .pickerStyle(.segmented)
        .controlSize(.small)
        .frame(maxWidth: 180)
        .accessibilityLabel("Page order")
    }
}
