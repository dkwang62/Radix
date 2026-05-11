import SwiftUI
import UIKit

extension FilterGridTab {
    func prepareBrowseHintIfNeeded() {
        guard !hasShownBrowseInteractionHintRow else { return }
        showBrowseInteractionHint = true
        hasShownBrowseInteractionHintRow = true
        store.showBrowseHelp = true
    }

    func returnToBrowse(proxy: ScrollViewProxy) {
        let anchorID = activeBrowseTileAnchorID()
        if let character = store.previewCharacter, store.selectedBrowseCollection == nil {
            focusBrowseGrid(on: character)
        }

        withAnimation {
            store.returnToBrowseGrid()
        }

        scrollToBrowseTile(anchorID, proxy: proxy)
    }

    func scrollToBrowseTile(_ anchorID: String?, proxy: ScrollViewProxy) {
        guard let anchorID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(anchorID, anchor: .center)
            }
        }
    }

    func scrollToPendingBrowseTarget(proxy: ScrollViewProxy) {
        guard let target = store.consumePendingBrowseScrollTarget() else { return }

        if let collectionID = target.collectionID,
           store.selectedBrowseCollectionID == collectionID {
            if let offset = target.offset {
                scrollToBrowseTile(imageTileAnchorID(offset), proxy: proxy)
                return
            }

            if let character = target.character,
               let offset = store.selectedBrowseCollection?.characters.firstIndex(of: character) {
                scrollToBrowseTile(imageTileAnchorID(offset), proxy: proxy)
                return
            }
        }

        if let character = target.character {
            focusBrowseGrid(on: character)
            scrollToBrowseTile(dictionaryTileAnchorID(character), proxy: proxy)
        }
    }

    func activeBrowseTileAnchorID() -> String? {
        if let collection = store.selectedBrowseCollection {
            if let targetOffset = collection.characters.indices.first(where: {
                store.imagePhraseHighlightRole(collectionID: collection.id, offset: $0) == .target
            }) {
                return imageTileAnchorID(targetOffset)
            }

            if let phraseOffset = collection.characters.indices.first(where: {
                store.imagePhraseHighlightRole(collectionID: collection.id, offset: $0) == .phraseMember
            }) {
                return imageTileAnchorID(phraseOffset)
            }

            if let character = store.previewCharacter,
               let offset = collection.characters.firstIndex(of: character) {
                return imageTileAnchorID(offset)
            }

            if let phraseCharacter = store.activeSidebarPhrasePreview?.word.first.map(String.init),
               let offset = collection.characters.firstIndex(of: phraseCharacter) {
                return imageTileAnchorID(offset)
            }

            return nil
        }

        if let character = store.previewCharacter {
            return dictionaryTileAnchorID(character)
        }

        if let phraseCharacter = store.activeSidebarPhrasePreview?.word.first.map(String.init) {
            return dictionaryTileAnchorID(phraseCharacter)
        }

        return nil
    }

    func imageTileAnchorID(_ offset: Int) -> String {
        "browse-image-tile-\(offset)"
    }

    func dictionaryTileAnchorID(_ character: String) -> String {
        "browse-dictionary-tile-\(character)"
    }

    func focusBrowseGrid(on character: String?) {
        guard let character else { return }

        if store.selectedBrowseCollection != nil {
            return
        }

        if let index = store.allGridItems.firstIndex(where: { $0.character == character }) {
            store.gridPage = GridPaging.pageForIndex(index, pageSize: store.gridBatchSize)
        }
    }

    var browseGridDescription: String {
        if let collection = store.selectedBrowseCollection {
            return "\(collection.characters.count) characters"
        }

        return store.gridSortMode == .componentFrequency ?
            "Characters most often used as components first." :
            "Most common characters first."
    }

    func beginManualCollection() {
        manualCollectionName = ""
        manualCollectionText = clipboardText()
        showBrowseSource = false
        showManualCollectionSheet = true
    }

    func saveManualCollection() {
        guard let collection = store.createCollection(
            name: manualCollectionName,
            sourceText: manualCollectionText,
            sourceType: .manual
        ) else { return }
        store.selectBrowseCollection(id: collection.id)
        manualCollectionName = ""
        manualCollectionText = ""
        showManualCollectionSheet = false
    }

    func clipboardText() -> String {
        #if canImport(UIKit)
        return UIPasteboard.general.string ?? ""
        #else
        return ""
        #endif
    }

    var activeBrowseFilterCount: Int {
        BrowseFilterSummary.activeCount(store: store)
    }

    var filterButtonTitle: String {
        activeBrowseFilterCount > 0 ? "Filters (\(activeBrowseFilterCount))" : "Filters"
    }
}
