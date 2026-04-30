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
    @State private var showBrowseFilters = false
    @State private var showManualCollectionSheet = false
    @State private var manualCollectionName = ""
    @State private var manualCollectionText = ""
    @State private var imageGridPage: Int = 0

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
                VStack(alignment: .leading, spacing: 10) {
                    Color.clear.frame(height: 0).id("browseTop")
                    // Animation Preview (phones only; sidebar handles iPad/Mac)
                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone,
                       let previewChar = store.previewCharacter {
                        standardPhoneCharacterPreview(
                            character: previewChar,
                            selectedCharacter: store.selectedCharacter,
                            onClear: { store.previewCharacter = nil }
                        )
                    }
                    #endif

                    browseSubjectSection

                    if let collection = store.selectedBrowseCollection {
                        // ── Image selected: show entire character set in reading order ──
                        imageGridContent(collection: collection, proxy: proxy)
                    } else {
                        // ── No image: smart grid with All / Components / Reading Order ──
                        smartGridContent(proxy: proxy)
                    }
                }
                .padding(.horizontal)
                .onChange(of: store.strokeMinFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.strokeMaxFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedRadicalFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedStructureFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedBrowseCollectionID) { _, _ in imageGridPage = 0 }
                .onChange(of: store.previewCharacter) { _, _ in
                    withAnimation {
                        proxy.scrollTo("browseTop", anchor: .top)
                    }
                }
            }
            .sheet(isPresented: $showBrowseFilters) {
                browseFiltersSheet
            }
            .sheet(isPresented: $showManualCollectionSheet) {
                manualCollectionSheet
            }
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

        VStack(alignment: .leading, spacing: 4) {
            Text("All \(total) characters from this image, in reading order.")
                .font(ResponsiveFont.caption2)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            browseInteractionHintRow
                .padding(.horizontal, 4)
        }
        .padding(.bottom, 4)

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
                    store.preview(character: character)
                    withAnimation { proxy.scrollTo("browseTop", anchor: .top) }
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
        HStack(alignment: .center, spacing: 12) {
            Picker("Sort", selection: Binding(get: {
                // If mode is somehow readingOrder with no image, fall back to characterFrequency
                store.gridSortMode == .readingOrder ? .characterFrequency : store.gridSortMode
            }, set: { store.setGridSortMode($0) })) {
                ForEach(GridSortMode.allCases.filter { $0 != .readingOrder }) { mode in
                    Text(browseSortLabel(for: mode)).tag(mode)
                }
            }
            .font(ResponsiveFont.subheadline)
            .pickerStyle(.segmented)

            CompactScriptFilterControl(selection: store.gridScriptFilter) { store.setGridScriptFilter($0) }

            Button {
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
        }

        VStack(alignment: .leading, spacing: 4) {
            Text(store.gridSortMode == .componentFrequency ?
                 "Characters most often used as components first." :
                 "Most common characters first.")
                .font(ResponsiveFont.caption2)
                .italic()
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
            browseInteractionHintRow
                .padding(.horizontal, 4)
        }
        .padding(.bottom, 4)

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
                    store.preview(character: item.character)
                    withAnimation { proxy.scrollTo("browseTop", anchor: .top) }
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

    private var browseSubjectSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 10) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(browseSubjectTitle)
                        .font(ResponsiveFont.headline)
                    Text(browseSubjectDetail)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                collectionMenu
            }

            if !store.favoriteCollections.isEmpty {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(store.favoriteCollections) { collection in
                            Button {
                                store.selectBrowseCollection(id: collection.id)
                            } label: {
                                Label(collection.name, systemImage: "star.fill")
                                    .lineLimit(1)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    }
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
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
        return "No image selected"
    }

    private var browseSubjectDetail: String {
        if store.selectedBrowseCollection == nil {
            return "Browse is showing the full dictionary."
        }
        return "Browse is limited to this page; filters still apply."
    }

    private var collectionMenu: some View {
        Menu {
            Button("No Image") {
                store.selectBrowseCollection(id: nil)
            }
            if !store.favoriteCollections.isEmpty {
                Section("Favorites") {
                    ForEach(store.favoriteCollections) { collection in
                        Button(collection.name) {
                            store.selectBrowseCollection(id: collection.id)
                        }
                    }
                }
            }
            if !store.allCollections.isEmpty {
                Section("Images") {
                    ForEach(store.allCollections) { collection in
                        Button(collection.name) {
                            store.selectBrowseCollection(id: collection.id)
                        }
                    }
                }
            }
        } label: {
            Label {
                Text("Image")
            } icon: {
                Text("📄")
            }
        }
        .buttonStyle(.bordered)
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
