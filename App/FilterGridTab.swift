import SwiftUI

struct InteractionHintRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @AppStorage("hasAnimatedInteractionHintRowV2") private var hasAnimatedInteractionHintRow = false

    let previewText: String
    let memoryText: String
    let copyText: String

    @State private var isPulsing = false
    @State private var pulseTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            hintSegment(icon: "cursorarrow", text: previewText)
            segmentDivider
            hintSegment(icon: "bookmark", text: memoryText)
            segmentDivider
            hintSegment(icon: "doc.on.doc", text: copyText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(Color(.secondarySystemBackground))
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isPulsing ? Color.accentColor.opacity(0.26) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPulsing ? 1.10 : 1.0)
        .shadow(color: Color.accentColor.opacity(isPulsing ? 0.34 : 0), radius: 16)
        .onAppear {
            schedulePulseIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                schedulePulseIfNeeded()
            } else {
                cancelPulse()
            }
        }
        .onDisappear {
            cancelPulse()
        }
    }

    private func hintSegment(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(0.9))
                .frame(width: 14, alignment: .center)

            Text(text)
                .foregroundStyle(Color.primary.opacity(0.72))
        }
        .font(ResponsiveFont.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var segmentDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
    }

    private func schedulePulseIfNeeded() {
        guard scenePhase == .active else { return }
        guard !hasAnimatedInteractionHintRow else { return }
        guard pulseTask == nil else { return }

        pulseTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            hasAnimatedInteractionHintRow = true

            guard !reduceMotion else {
                pulseTask = nil
                return
            }

            await MainActor.run {
                runPulseSequence()
            }

            try? await Task.sleep(for: .milliseconds(3000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                pulseTask = nil
            }
        }
    }

    private func cancelPulse() {
        pulseTask?.cancel()
        pulseTask = nil
        isPulsing = false
    }

    @MainActor
    private func runPulseSequence() {
        Task { @MainActor in
            for cycle in 0..<3 {
                withAnimation(.easeInOut(duration: 0.30)) {
                    isPulsing = true
                }

                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.easeInOut(duration: 0.26)) {
                    isPulsing = false
                }

                if cycle < 2 {
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
        }
    }
}

struct FilterGridTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @AppStorage("hasShownBrowseInteractionHintRowV1") private var hasShownBrowseInteractionHintRow = false
    @State private var showBrowseFilters = false
    @State private var showManualCollectionSheet = false
    @State private var showBrowseSource = false
    @State private var showBrowseInteractionHint = false
    @State private var manualCollectionName = ""
    @State private var manualCollectionText = ""
    @State private var imageGridPage: Int = 0
    @State private var pendingDeleteCollection: CharacterCollection?
    @State private var editingCollection: CharacterCollection?
    @State private var editingCollectionName = ""
    @State private var editingCollectionText = ""
    @State private var collectionEditorError: String?
    @FocusState private var editingCharactersFocused: Bool

    // ── Image-mode grid (entirely separate from the smart grid) ──────────────
    private var imageGridBatchSize: Int {
        #if targetEnvironment(macCatalyst)
        return 225
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? 96 : 120
        #endif
    }

    private func imageGridPageCount(for collection: CharacterCollection) -> Int {
        max(1, Int(ceil(Double(collection.characters.count) / Double(imageGridBatchSize))))
    }

    private func imagePagedCharacters(for collection: CharacterCollection) -> [(offset: Int, character: String)] {
        let total = collection.characters.count
        let safePage = min(imageGridPage, max(0, imageGridPageCount(for: collection) - 1))
        let start = safePage * imageGridBatchSize
        let end = min(start + imageGridBatchSize, total)
        guard start < end else { return [] }
        return collection.characters[start..<end].enumerated().map { (start + $0.offset, $0.element) }
    }

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

    @ViewBuilder
    private var browseInteractionHintRow: some View {
        InteractionHintRow(
            previewText: isRunningOnMac ? "Click to preview" : "Tap to preview",
            memoryText: "Preview adds to 🕘",
            copyText: isRunningOnMac ? "Right-click to copy" : "Long-press to copy"
        )
    }
    
    private var columns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 40, maximum: 80), spacing: 10), count: 15)
        #else
        // iPhone: fewer columns (8) to give pinyin room to stay on one line
        return Array(repeating: GridItem(.flexible(minimum: 32, maximum: 64), spacing: 8), count: 8)
        #endif
    }

    private var fontSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return 24
        #endif
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: isPhoneBrowseLayout ? 6 : 10) {
                    Color.clear.frame(height: 0).id("browseTop")
                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone,
                       let previewChar = store.previewCharacter {
                        phoneBrowsePreview(character: previewChar)
                    } else {
                        browseContent(proxy: proxy)
                    }
                    #else
                    browseContent(proxy: proxy)
                    #endif
                }
                .padding(.horizontal)
                .onChange(of: store.strokeMinFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.strokeMaxFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedRadicalFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedStructureFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedBrowseCollectionID) { _, _ in imageGridPage = 0 }
                .onChange(of: store.previewCharacter) { _, newValue in
                    focusBrowseGrid(on: newValue)
                    withAnimation {
                        proxy.scrollTo("browseTop", anchor: .top)
                    }
                }
                .onChange(of: store.selectedCharacter) { _, newValue in
                    focusBrowseGrid(on: newValue)
                    withAnimation {
                        proxy.scrollTo("browseTop", anchor: .top)
                    }
                }
                .onAppear {
                    prepareBrowseHintIfNeeded()
                }
            }
            .sheet(isPresented: $showBrowseFilters) {
                browseFiltersSheet
            }
            .sheet(isPresented: $showManualCollectionSheet) {
                manualCollectionSheet
            }
            .sheet(item: $editingCollection) { collection in
                editCollectionSheet(collection)
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
        browseSourceDisclosure(description: browseGridDescription)
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
    private func phoneBrowsePreview(character: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Button {
                withAnimation {
                    store.previewCharacter = nil
                }
            } label: {
                Label("Browse", systemImage: "chevron.left")
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                    .foregroundStyle(Color.accentColor)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
            }
            .buttonStyle(.plain)

            standardPhoneCharacterPreview(
                character: character,
                selectedCharacter: store.selectedCharacter,
                showAddToMemoryButton: false,
                onClear: { store.previewCharacter = nil }
            )
        }
    }

    // ── Image grid: entire character sequence, unfiltered, reading order ────
    @ViewBuilder
    private func imageGridContent(collection: CharacterCollection, proxy: ScrollViewProxy) -> some View {
        let total = collection.characters.count
        let pageCount = imageGridPageCount(for: collection)
        let safePage = min(imageGridPage, max(0, pageCount - 1))
        let pagedItems = imagePagedCharacters(for: collection)
        let rangeStart = safePage * imageGridBatchSize + 1
        let rangeEnd = min((safePage + 1) * imageGridBatchSize, total)

        if !isPhoneBrowseLayout {
            VStack(alignment: .leading, spacing: 4) {
                Text("All \(total) characters from this image, in reading order.")
                    .font(ResponsiveFont.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                browseHintIfNeeded
                    .padding(.horizontal, 4)
            }
            .padding(.bottom, 4)
        }

        HStack {
            Button("◀ Prev") { imageGridPage = max(0, safePage - 1) }
                .font(ResponsiveFont.subheadline)
                .disabled(safePage == 0)
            Spacer()
            Text("\(rangeStart)–\(rangeEnd) of \(total)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Next ▶") { imageGridPage = min(pageCount - 1, safePage + 1) }
                .font(ResponsiveFont.subheadline)
                .disabled(safePage + 1 >= pageCount)
        }

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(pagedItems, id: \.offset) { offset, character in
                let isActive = character == store.previewCharacter || character == store.selectedCharacter
                let pinyin = store.item(for: character)?.pinyinText ?? ""
                Button {
                    store.speakCharacter(character)
                    store.preview(character: character)
                    scrollBrowseTopIfNeeded(proxy)
                } label: {
                    VStack(spacing: 2) {
                        Text(character)
                            .font(.system(size: fontSize))
                            .copyCharacterContextMenu(character, pinyin: pinyin)
                        Text(pinyin.isEmpty ? " " : pinyin)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        if store.isFavorite(character) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.yellow)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    // ── Smart grid: All / Components with filters ────────────────────────────
    @ViewBuilder
    private func smartGridContent(proxy: ScrollViewProxy) -> some View {
        let description = store.gridSortMode == .componentFrequency ?
            "Characters most often used as components first." :
            "Most common characters first."

        if isPhoneBrowseLayout {
            EmptyView()
        } else {
            smartGridControls

            VStack(alignment: .leading, spacing: 4) {
                Text(description)
                    .font(ResponsiveFont.caption2)
                    .italic()
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 4)
                browseHintIfNeeded
                    .padding(.horizontal, 4)
            }
            .padding(.bottom, 4)
        }

        HStack {
            Button("◀ Prev") { store.previousGridPage() }
                .font(ResponsiveFont.subheadline)
                .disabled(store.gridPage == 0)
            Spacer()
            let totalCount = store.allGridItems.count
            Text("\(store.gridPage * store.gridBatchSize + 1)–\(min((store.gridPage + 1) * store.gridBatchSize, totalCount)) of \(totalCount)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Spacer()
            Button("Next ▶") { store.nextGridPage() }
                .font(ResponsiveFont.subheadline)
                .disabled(store.gridPage + 1 >= store.gridPageCount)
        }

        LazyVGrid(columns: columns, spacing: 6) {
            ForEach(store.pagedGridItems, id: \.character) { item in
                let isActive = item.character == store.previewCharacter || item.character == store.selectedCharacter
                Button {
                    store.speakCharacter(item.character)
                    store.preview(character: item.character)
                    scrollBrowseTopIfNeeded(proxy)
                } label: {
                    VStack(spacing: 2) {
                        Text(item.character)
                            .font(.system(size: fontSize))
                            .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                        Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 6)
                    .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(RoundedRectangle(cornerRadius: 8).stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2))
                    .overlay(alignment: .topTrailing) {
                        if store.isFavorite(item.character) {
                            Image(systemName: "star.fill")
                                .font(.system(size: 14))
                                .foregroundStyle(.yellow)
                                .padding(6)
                        }
                    }
                }
                .buttonStyle(.plain)
            }
        }
    }

    @ViewBuilder
    private var smartGridControls: some View {
        let sortPicker = Picker("Sort", selection: Binding(get: {
            // If mode is somehow readingOrder with no image, fall back to characterFrequency
            store.gridSortMode == .readingOrder ? .characterFrequency : store.gridSortMode
        }, set: { store.setGridSortMode($0) })) {
            ForEach(GridSortMode.allCases.filter { $0 != .readingOrder }) { mode in
                Text(browseSortLabel(for: mode)).tag(mode)
            }
        }
        .font(ResponsiveFont.subheadline)
        .pickerStyle(.segmented)

        let filterButton = Button {
            showBrowseFilters = true
        } label: {
            Label(filterButtonTitle, systemImage: activeBrowseFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)

        if isPhoneBrowseLayout {
            VStack(alignment: .leading, spacing: 10) {
                sortPicker
                HStack(spacing: 10) {
                    CompactScriptFilterControl(selection: store.gridScriptFilter) { store.setGridScriptFilter($0) }
                    filterButton
                }
            }
        } else {
            HStack(alignment: .center, spacing: 12) {
                sortPicker
                CompactScriptFilterControl(selection: store.gridScriptFilter) { store.setGridScriptFilter($0) }
                filterButton
            }
        }
    }

    @ViewBuilder
    private var browseHintIfNeeded: some View {
        if showBrowseInteractionHint && store.showBrowseHelp {
            browseInteractionHintRow
        }
    }

    private func browseSourceDisclosure(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showBrowseSource) {
            VStack(alignment: .leading, spacing: 10) {
                browseSourceOptions

                if isPhoneBrowseLayout, store.selectedBrowseCollection == nil {
                    smartGridControls
                }

                if isPhoneBrowseLayout {
                    Text(description)
                        .font(ResponsiveFont.caption2)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 4)
                }
            }
            .padding(.top, 8)
            } label: {
                HStack(spacing: 8) {
                    Image(systemName: "tray.full")
                        .foregroundStyle(Color.accentColor)
                    VStack(alignment: .leading, spacing: 1) {
                        Text("Source")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                        Text(browseSubjectTitle)
                            .font(ResponsiveFont.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    Spacer()
                }
            }

            if let collection = store.selectedBrowseCollection {
                selectedImageSourceActions(collection)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func selectedImageSourceActions(_ collection: CharacterCollection) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            readBrowseSourceButton(collection)

            LazyVGrid(columns: [GridItem(.adaptive(minimum: 140), spacing: 8)], spacing: 8) {
                Button {
                    beginEditing(collection)
                } label: {
                    Label("Edit", systemImage: "pencil")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)

                Button {
                    store.goToAILinkTask4(collection: collection)
                } label: {
                    Label("Extract Phrases", systemImage: "quote.bubble")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)

                Button(role: .destructive) {
                    pendingDeleteCollection = collection
                } label: {
                    Label("Delete", systemImage: "trash")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
            }
        }
    }

    private func readBrowseSourceButton(_ collection: CharacterCollection) -> some View {
        Button {
            _ = store.speakCharacters(in: collection.characters.joined())
        } label: {
            Label("Read Aloud", systemImage: "speaker.wave.2")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.bordered)
        .disabled(collection.characters.isEmpty)
    }

    private func beginEditing(_ collection: CharacterCollection) {
        editingCollectionName = collection.name
        editingCollectionText = collection.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = collection
    }

    private func editCollectionSheet(_ collection: CharacterCollection) -> some View {
        NavigationStack {
            Form {
                Section("Image") {
                    TextField("Name", text: $editingCollectionName)
                }

                Section("Characters") {
                    TextEditor(text: $editingCollectionText)
                        .frame(minHeight: 140)
                        .focused($editingCharactersFocused)
                    Text("Paste or type Chinese text here. Radix will keep the recognized characters for this saved image.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }

                if let collectionEditorError {
                    Section {
                        Text(collectionEditorError)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.red)
                    }
                }
            }
            .navigationTitle("Edit Saved Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        editingCollection = nil
                        collectionEditorError = nil
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveEditedCollection(collection)
                    }
                }
            }
        }
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

            ForEach(store.allCollections) { collection in
                sourceOptionButton(
                    title: collection.name,
                    subtitle: collectionSubtitle(for: collection),
                    isSelected: store.selectedBrowseCollectionID == collection.id,
                    systemImage: collection.isFavorite ? "star.fill" : "photo.on.rectangle"
                ) {
                    store.selectBrowseCollection(id: collection.id)
                }
            }
        }
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
            HStack(spacing: 10) {
                Image(systemName: systemImage)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                    .frame(width: 20)

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(ResponsiveFont.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                    Text(subtitle)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 8)

                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(Color.accentColor)
                }
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(isSelected ? Color.accentColor.opacity(0.10) : Color(.secondarySystemBackground).opacity(0.45))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func prepareBrowseHintIfNeeded() {
        guard !hasShownBrowseInteractionHintRow else { return }
        showBrowseInteractionHint = true
        hasShownBrowseInteractionHintRow = true
        store.showBrowseHelp = true
    }

    private func scrollBrowseTopIfNeeded(_ proxy: ScrollViewProxy) {
        withAnimation { proxy.scrollTo("browseTop", anchor: .top) }
    }

    private func focusBrowseGrid(on character: String?) {
        guard let character else { return }

        if let collection = store.selectedBrowseCollection,
           let index = collection.characters.firstIndex(of: character) {
            imageGridPage = index / imageGridBatchSize
            return
        }

        if let index = store.allGridItems.firstIndex(where: { $0.character == character }) {
            store.gridPage = index / store.gridBatchSize
        }
    }

    private var browseGridDescription: String {
        if let collection = store.selectedBrowseCollection {
            return "All \(collection.characters.count) characters from this image, in reading order."
        }

        return store.gridSortMode == .componentFrequency ?
            "Characters most often used as components first." :
            "Most common characters first."
    }

    private var browseSubjectTitle: String {
        if let collection = store.selectedBrowseCollection {
            let total = collection.characters.count
            let unique = collection.uniqueCharacters.count
            if total == unique {
                return "Image: \(collection.name) (\(unique) characters)"
            } else {
                return "Image: \(collection.name) (\(unique) unique / \(total) total)"
            }
        }
        return "Dictionary"
    }

    private func collectionSubtitle(for collection: CharacterCollection) -> String {
        let total = collection.characters.count
        let unique = collection.uniqueCharacters.count
        if total == unique {
            return "\(unique) characters"
        }
        return "\(unique) unique / \(total) total"
    }

    private var manualCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Image") {
                    TextField("Name", text: $manualCollectionName)
                    TextEditor(text: $manualCollectionText)
                        .frame(minHeight: 180)
                }

                Section {
                    Text("\(CaptureTextExtractor.uniqueCharacters(in: manualCollectionText).count) unique Chinese characters detected.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("New Image")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showManualCollectionSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveManualCollection()
                    }
                    .disabled(CaptureTextExtractor.uniqueCharacters(in: manualCollectionText).isEmpty)
                }
            }
        }
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
        var count = 0
        if store.strokeMinFilter > 0 { count += 1 }
        if store.selectedRadicalFilter != "none" { count += 1 }
        if store.selectedStructureFilter != "none" { count += 1 }
        return count
    }

    private var filterButtonTitle: String {
        activeBrowseFilterCount > 0 ? "Filters (\(activeBrowseFilterCount))" : "Filters"
    }

    private var browseFiltersSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Strokes")
                            .font(ResponsiveFont.caption.bold())
                            .foregroundStyle(.secondary)
                        StrokeRangeSlider(minValue: $store.strokeMinFilter, maxValue: $store.strokeMaxFilter)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        radicalPicker
                        structurePicker
                    }
                }
                .padding()
            }
            .navigationTitle("Browse Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if activeBrowseFilterCount > 0 {
                        Button("Reset") {
                            store.strokeMinFilter = 0
                            store.selectedRadicalFilter = "none"
                            store.selectedStructureFilter = "none"
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showBrowseFilters = false
                    }
                }
            }
            .presentationDetents(sizeClass == .compact ? [.medium, .large] : [.large])
        }
    }

    private var radicalPicker: some View {
        HStack(spacing: 8) {
            Text("Radical")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Radical", selection: $store.selectedRadicalFilter) {
                ForEach(store.availableRadicalFilters, id: \.self) { radical in
                    Text(store.radicalFilterLabel(radical)).tag(radical)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var structurePicker: some View {
        HStack(spacing: 8) {
            Text("Structure")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Structure", selection: $store.selectedStructureFilter) {
                ForEach(store.availableStructureFilters, id: \.self) { structKey in
                    Text(structKey).tag(structKey)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
