import SwiftUI
import UIKit

struct FilterGridTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @AppStorage("hasShownBrowseInteractionHintRowV1") private var hasShownBrowseInteractionHintRow = false
    @AppStorage("browseImageScriptMode") private var browseImageScriptMode = "simplified"
    @State private var showBrowseFilters = false
    @State private var showManualCollectionSheet = false
    @State private var showBrowseSource = false
    @State private var showBrowseInteractionHint = false
    @State private var manualCollectionName = ""
    @State private var manualCollectionText = ""
    @State private var pendingDeleteCollection: CharacterCollection?
    @State private var editingCollection: CharacterCollection?
    @State private var editingCollectionName = ""
    @State private var editingCollectionText = ""
    @State private var collectionEditorError: String?

    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    private var isPhoneBrowseLayout: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private var isPhoneBrowsePreviewActive: Bool {
        isPhoneBrowseLayout && (store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil)
    }

    private var browseGridLayout: BrowseGridLayout {
        .current
    }

    @ViewBuilder
    private var browseInteractionHintRow: some View {
        InteractionHintRow(
            previewText: isRunningOnMac ? "Click to preview" : "Tap to preview",
            memoryText: "Preview adds to 🕘",
            copyText: isRunningOnMac ? "Right-click to copy" : "Long-press to copy"
        )
    }
    
    private var columns: [GridItem] {
        browseGridLayout.gridColumns
    }

    private var fontSize: CGFloat {
        browseGridLayout.characterFontSize
    }

    private var useTraditionalBrowseImageScript: Bool {
        browseImageScriptMode == "traditional"
    }

    var body: some View {
        ScrollViewReader { proxy in
            Group {
                if isPhoneBrowsePreviewActive {
                    ScrollView {
                        VStack(alignment: .leading, spacing: 10) {
                            Color.clear.frame(height: 0).id("browseTop")
                            #if !targetEnvironment(macCatalyst)
                            if UIDevice.current.userInterfaceIdiom == .phone {
                                phoneBrowsePreview(proxy: proxy)
                            }
                            #endif
                        }
                        .padding(.horizontal)
                    }
                } else {
                    VStack(alignment: .leading, spacing: 0) {
                        browseSourceDisclosure(description: browseGridDescription)
                            .padding(.horizontal)

                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                Color.clear.frame(height: 0).id("browseTop")
                                browseContent(proxy: proxy)
                            }
                            .padding(.horizontal)
                        }
                    }
                }
            }
            .onChange(of: store.strokeMinFilter) { _, _ in store.gridPage = 0 }
            .onChange(of: store.strokeMaxFilter) { _, _ in store.gridPage = 0 }
            .onChange(of: store.selectedRadicalFilter) { _, _ in store.gridPage = 0 }
            .onChange(of: store.selectedStructureFilter) { _, _ in store.gridPage = 0 }
            .onChange(of: store.previewCharacter) { _, newValue in
                if let newValue {
                    if store.selectedBrowseCollection == nil {
                        store.highlightBrowseDictionaryCharacter(newValue)
                    }
                    focusBrowseGrid(on: newValue)
                    scrollToBrowseTile(activeBrowseTileAnchorID() ?? dictionaryTileAnchorID(newValue), proxy: proxy)
                } else {
                    scrollToPendingBrowseTarget(proxy: proxy)
                }
            }
            .onChange(of: store.activeSidebarPhrasePreview?.word) { _, newValue in
                if newValue == nil {
                    scrollToPendingBrowseTarget(proxy: proxy)
                }
            }
            .onChange(of: store.browseMemoryHighlightOffsets) { _, _ in
                scrollToPendingBrowseTarget(proxy: proxy)
            }
            .onAppear {
                prepareBrowseHintIfNeeded()
                scrollToPendingBrowseTarget(proxy: proxy)
            }
            .sheet(isPresented: $showBrowseFilters) {
                BrowseFiltersSheet(sizeClass: sizeClass) {
                    showBrowseFilters = false
                }
                .environmentObject(store)
            }
            .sheet(isPresented: $showManualCollectionSheet) {
                ManualBrowseCollectionSheet(
                    name: $manualCollectionName,
                    text: $manualCollectionText,
                    onCancel: { showManualCollectionSheet = false },
                    onSave: saveManualCollection
                )
            }
            .sheet(item: $editingCollection) { collection in
                EditBrowseCollectionSheet(
                    collection: collection,
                    name: $editingCollectionName,
                    text: $editingCollectionText,
                    error: collectionEditorError,
                    onCancel: {
                        editingCollection = nil
                        collectionEditorError = nil
                    },
                    onSave: {
                        saveEditedCollection(collection)
                    }
                )
            }
            .alert("Delete Saved Image?", isPresented: Binding(
                get: { pendingDeleteCollection != nil },
                set: { if !$0 { pendingDeleteCollection = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let collection = pendingDeleteCollection {
                        store.deleteCollection(id: collection.id)
                    }
                    pendingDeleteCollection = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingDeleteCollection = nil
                }
            } message: {
                if let collection = pendingDeleteCollection {
                    Text("Delete “\(collection.name)” from saved images?")
                }
            }
        }
    }

    @ViewBuilder
    private func browseContent(proxy: ScrollViewProxy) -> some View {
        if isPhoneBrowseLayout {
            browseHintIfNeeded
        }

        if let collection = store.selectedBrowseCollection {
            // ── Image selected: show entire character set in reading order ──
            imageGridContent(collection: collection, proxy: proxy)
        } else {
            // ── No image: smart grid with All / Components / Reading Order ──
            smartGridContent(proxy: proxy)
        }
    }

    @ViewBuilder
    private func phoneBrowsePreview(proxy: ScrollViewProxy) -> some View {
        BrowsePhonePreview(
            phrase: store.activeSidebarPhrasePreview,
            character: store.previewCharacter,
            onReturn: { returnToBrowse(proxy: proxy) }
        )
        .environmentObject(store)
    }

    private var dictionaryGridSwipeGesture: some Gesture {
        DragGesture(minimumDistance: 35, coordinateSpace: .local)
            .onEnded { value in
                let horizontal = value.translation.width
                let vertical = value.translation.height
                guard abs(horizontal) > 70, abs(horizontal) > abs(vertical) * 1.35 else { return }

                withAnimation(.easeInOut(duration: 0.18)) {
                    if horizontal < 0 {
                        store.nextGridPage()
                    } else {
                        store.previousGridPage()
                    }
                }
            }
    }

    private var dictionaryGridFooter: some View {
        DictionaryGridFooter(
            totalCount: store.allGridItems.count,
            page: store.gridPage,
            pageSize: store.gridBatchSize,
            pageCount: store.gridPageCount,
            onPrevious: {
                store.previousGridPage()
            },
            onNext: {
                store.nextGridPage()
            }
        )
    }

    @ViewBuilder
    private var smartGridControls: some View {
        let isComponents = store.gridSortMode == .componentFrequency
        let componentsToggle = Button {
            store.setGridSortMode(isComponents ? .characterFrequency : .componentFrequency)
        } label: {
            Text("Components")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(isComponents ? Color.accentColor : Color(.secondarySystemBackground))
                .foregroundStyle(isComponents ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)

        let filterButton = Button {
            showBrowseFilters = true
        } label: {
            Text("▽")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 10)
                .padding(.vertical, 6)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(filterButtonTitle)

        HStack(alignment: .center, spacing: 8) {
            componentsToggle
            CompactScriptFilterControl(selection: store.gridScriptFilter) { store.setGridScriptFilter($0) }
            filterButton
        }
    }

    // ── Image grid: entire character sequence, unfiltered, reading order ────
    @ViewBuilder
    private func imageGridContent(collection: CharacterCollection, proxy: ScrollViewProxy) -> some View {
        let allItems = Array(collection.characters.enumerated())

        if !isPhoneBrowseLayout {
            browseHintIfNeeded
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(allItems, id: \.offset) { offset, character in
                let displayCharacter = browseImageDisplayCharacter(character)
                let highlightRole = store.imagePhraseHighlightRole(collectionID: collection.id, offset: offset)
                let isMemoryHighlighted = store.isBrowseMemoryHighlighted(collectionID: collection.id, offset: offset)
                let isActive = highlightRole == .target
                let pinyin = store.item(for: character)?.pinyinText ?? ""
                Button {
                    let shouldScroll = store.handleImageCharacterTap(character, offset: offset)
                    if shouldScroll {
                        scrollToBrowseTile(activeBrowseTileAnchorID() ?? imageTileAnchorID(offset), proxy: proxy)
                }
            } label: {
                    BrowseGridTileLabel(
                        displayCharacter: displayCharacter,
                        pinyin: pinyin,
                        fontSize: fontSize,
                        isFavorite: store.isFavorite(character),
                        background: BrowseImageTileStyle.background(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                        stroke: BrowseImageTileStyle.stroke(isActive: isActive, highlightRole: highlightRole, isMemoryHighlighted: isMemoryHighlighted),
                        strokeWidth: highlightRole == nil ? 2 : 2.5
                    ) {
                        store.previewImageCharacter(character, offset: offset, announce: false)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                            NotificationCenter.default.post(name: .radixShowPhraseTable, object: character)
                        }
                    }
                }
                .buttonStyle(.plain)
                .id(imageTileAnchorID(offset))
            }
        }
    }

    // ── Smart grid: All / Components with filters ────────────────────────────
    @ViewBuilder
    private func smartGridContent(proxy: ScrollViewProxy) -> some View {
        if !isPhoneBrowseLayout {
            browseHintIfNeeded
                .padding(.horizontal, 4)
                .padding(.bottom, 4)
        }

        LazyVGrid(columns: columns, spacing: 0) {
            ForEach(store.pagedGridItems, id: \.character) { item in
                let isActive = item.character == store.previewCharacter || item.character == store.browseHighlightedCharacter
                Button {
                    store.highlightBrowseDictionaryCharacter(item.character)
                    store.speakCharacter(item.character)
                    store.preview(character: item.character)
                    scrollToBrowseTile(dictionaryTileAnchorID(item.character), proxy: proxy)
                } label: {
                    BrowseGridTileLabel(
                        displayCharacter: item.character,
                        pinyin: item.pinyinText,
                        fontSize: fontSize,
                        isFavorite: store.isFavorite(item.character),
                        background: isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground),
                        stroke: isActive ? Color.accentColor : Color.clear
                    )
                }
                .buttonStyle(.plain)
                .id(dictionaryTileAnchorID(item.character))
            }
        }
        .simultaneousGesture(dictionaryGridSwipeGesture)

        dictionaryGridFooter
    }

    @ViewBuilder
    private var browseHintIfNeeded: some View {
        if showBrowseInteractionHint && store.showBrowseHelp {
            browseInteractionHintRow
        }
    }

    @ViewBuilder
    private func browseSourceDisclosure(description: String) -> some View {
        let selectedCollection = store.selectedBrowseCollection

        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showBrowseSource) {
                VStack(alignment: .leading, spacing: 10) {
                    browseSourceOptions

                    if isPhoneBrowseLayout, selectedCollection == nil {
                        Text(description)
                            .font(ResponsiveFont.caption2)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.top, 8)
            } label: {
                if let selectedCollection {
                    selectedImageSourceLabel(selectedCollection)
                } else {
                    browseSourceLabel(collection: nil)
                }
            }
        }
        .padding(selectedCollection == nil ? 10 : 8)
        .background(Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func selectedImageSourceLabel(_ collection: CharacterCollection) -> some View {
        HStack(spacing: 8) {
            selectedImageSourceActions(collection)
            Spacer(minLength: 0)
        }
    }

    private func browseSourceLabel(collection: CharacterCollection?) -> some View {
        HStack(spacing: 8) {
            if collection == nil {
                smartGridControls
            } else {
                Spacer()
            }
            Spacer(minLength: 0)
            Text("Source")
                .font(ResponsiveFont.caption.weight(.semibold))
                .lineLimit(1)
        }
    }

    private func selectedImageSourceActions(_ collection: CharacterCollection) -> some View {
        HStack(spacing: 8) {
            Button {
                beginEditing(collection)
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Edit")

            CollectionAITaskMenu(collection: collection) { taskID in
                store.goToAILinkCollectionTask(collection: collection, taskID: taskID)
            }

            BrowseImageScriptToggle(mode: $browseImageScriptMode)

            readBrowseSourceButton(collection)
        }
    }

    private func readBrowseSourceButton(_ collection: CharacterCollection) -> some View {
        Button {
            _ = store.speakCharacters(in: browseImageDisplayText(collection.characters.joined()))
        } label: {
            Image(systemName: "speaker.wave.2")
                .frame(width: 34)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(collection.characters.isEmpty)
        .accessibilityLabel("Read Aloud")
    }

    private func browseImageDisplayCharacter(_ character: String) -> String {
        browseImageDisplayText(character)
    }

    private func browseImageDisplayText(_ text: String) -> String {
        useTraditionalBrowseImageScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    private func beginEditing(_ collection: CharacterCollection) {
        editingCollectionName = collection.name
        editingCollectionText = collection.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = collection
    }

    private func saveEditedCollection(_ collection: CharacterCollection) {
        guard let updated = store.updateCollection(
            id: collection.id,
            newName: editingCollectionName,
            sourceText: editingCollectionText
        ) else {
            collectionEditorError = "Enter a name and at least one Chinese character that exists in Radix."
            return
        }

        editingCollectionName = updated.name
        editingCollectionText = updated.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = nil
    }

    private var browseSourceOptions: some View {
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
                subtitle: "Paste Chinese text and save it as an image source",
                systemImage: "doc.on.clipboard"
            ) {
                beginManualCollection()
            }

            ForEach(store.allCollections) { collection in
                sourceCollectionRow(collection)
            }
        }
    }

    private func sourceActionButton(
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

    private func sourceCollectionRow(_ collection: CharacterCollection) -> some View {
        let isSelected = store.selectedBrowseCollectionID == collection.id
        return SourceCollectionRow(
            collection: collection,
            isSelected: isSelected,
            thumbnail: sourceThumbnailImage(for: collection)
        ) {
            store.selectBrowseCollection(id: collection.id)
            withAnimation {
                showBrowseSource = false
            }
        } onDelete: {
            pendingDeleteCollection = collection
        }
    }

    private func sourceThumbnailImage(for collection: CharacterCollection) -> UIImage? {
        guard let data = collection.thumbnailJPEGData else { return nil }
        return UIImage(data: data)
    }

    private func sourceOptionButton(
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

    private func prepareBrowseHintIfNeeded() {
        guard !hasShownBrowseInteractionHintRow else { return }
        showBrowseInteractionHint = true
        hasShownBrowseInteractionHintRow = true
        store.showBrowseHelp = true
    }

    private func returnToBrowse(proxy: ScrollViewProxy) {
        let anchorID = activeBrowseTileAnchorID()
        if let character = store.previewCharacter, store.selectedBrowseCollection == nil {
            focusBrowseGrid(on: character)
        }

        withAnimation {
            store.clearBrowsePreview()
        }

        scrollToBrowseTile(anchorID, proxy: proxy)
    }

    private func scrollToBrowseTile(_ anchorID: String?, proxy: ScrollViewProxy) {
        guard let anchorID else { return }
        DispatchQueue.main.async {
            withAnimation(.easeInOut(duration: 0.22)) {
                proxy.scrollTo(anchorID, anchor: .center)
            }
        }
    }

    private func scrollToPendingBrowseTarget(proxy: ScrollViewProxy) {
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

    private func activeBrowseTileAnchorID() -> String? {
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

    private func imageTileAnchorID(_ offset: Int) -> String {
        "browse-image-tile-\(offset)"
    }

    private func dictionaryTileAnchorID(_ character: String) -> String {
        "browse-dictionary-tile-\(character)"
    }

    private func focusBrowseGrid(on character: String?) {
        guard let character else { return }

        if store.selectedBrowseCollection != nil {
            return
        }

        if let index = store.allGridItems.firstIndex(where: { $0.character == character }) {
            store.gridPage = GridPaging.pageForIndex(index, pageSize: store.gridBatchSize)
        }
    }

    private var browseGridDescription: String {
        if let collection = store.selectedBrowseCollection {
            return "\(collection.characters.count) characters"
        }

        return store.gridSortMode == .componentFrequency ?
            "Characters most often used as components first." :
            "Most common characters first."
    }

    private var browseSubjectTitle: String {
        if let collection = store.selectedBrowseCollection {
            return "Image: \(collection.name) (\(collection.characters.count))"
        }
        return "Dictionary"
    }

    private func collectionSubtitle(for collection: CharacterCollection) -> String {
        "\(collection.characters.count) characters"
    }

    private func beginManualCollection() {
        manualCollectionName = ""
        manualCollectionText = clipboardText()
        showBrowseSource = false
        showManualCollectionSheet = true
    }

    private func saveManualCollection() {
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

    private func clipboardText() -> String {
        #if canImport(UIKit)
        return UIPasteboard.general.string ?? ""
        #else
        return ""
        #endif
    }

    private func browseSortLabel(for mode: GridSortMode) -> String {
        switch mode {
        case .readingOrder:
            return "Reading Order"
        case .componentFrequency:
            return "Components (\(store.gridFilteredComponentCount))"
        case .characterFrequency:
            return "All (\(store.gridFilteredAllCount))"
        }
    }

    private var activeBrowseFilterCount: Int {
        BrowseFilterSummary.activeCount(store: store)
    }

    private var filterButtonTitle: String {
        activeBrowseFilterCount > 0 ? "Filters (\(activeBrowseFilterCount))" : "Filters"
    }
}
