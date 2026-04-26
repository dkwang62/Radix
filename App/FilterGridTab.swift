import SwiftUI

struct FilterGridTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) var sizeClass
    @State private var showBrowseFilters = false
    @State private var showManualCollectionSheet = false
    @State private var manualCollectionName = ""
    @State private var manualCollectionText = ""

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
        HStack(spacing: 10) {
            hintChip(icon: "cursorarrow", text: isRunningOnMac ? "Click Preview" : "Tap Preview")
            hintChip(icon: "cursorarrow.click.2", text: isRunningOnMac ? "Double-click or Memory" : "Double-tap or Memory")
            HStack(spacing: 4) {
                Text(isRunningOnMac ? "Right-click" : "Long-press")
                Image(systemName: "doc.on.doc")
            }
            .font(ResponsiveFont.caption)
            .foregroundStyle(.secondary)
        }
        .lineLimit(1)
        .minimumScaleFactor(0.8)
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

                    HStack(alignment: .center, spacing: 12) {
                        Picker("Sort", selection: Binding(get: {
                            store.gridSortMode
                        }, set: { store.setGridSortMode($0) })) {
                            ForEach(GridSortMode.allCases) { mode in
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
                        Text("\(store.gridPage * store.gridBatchSize + 1)-\(min((store.gridPage + 1) * store.gridBatchSize, store.allGridItems.count)) of \(store.allGridItems.count)")
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
                                withAnimation {
                                    proxy.scrollTo("browseTop", anchor: .top)
                                }
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
                                .overlay(
                                    RoundedRectangle(cornerRadius: 8)
                                        .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                                )
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
                            .simultaneousGesture(
                                TapGesture(count: 2).onEnded {
                                    store.select(character: item.character)
                                }
                            )
                        }
                    }
                }
                .padding(.horizontal)
                .onChange(of: store.strokeMinFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.strokeMaxFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedRadicalFilter) { _, _ in store.gridPage = 0 }
                .onChange(of: store.selectedStructureFilter) { _, _ in store.gridPage = 0 }
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
                if let collection = store.selectedBrowseCollection {
                    Button {
                        store.toggleFavoriteCollection(id: collection.id)
                    } label: {
                        Image(systemName: collection.isFavorite ? "star.fill" : "star")
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel(collection.isFavorite ? "Remove page from favorites" : "Favorite page")
                }
                collectionMenu
                Button {
                    showManualCollectionSheet = true
                } label: {
                    Label("New", systemImage: "plus")
                }
                .buttonStyle(.bordered)
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
            return "Page: \(collection.name) (\(collection.characters.count) characters)"
        }
        return "All Characters"
    }

    private var browseSubjectDetail: String {
        if store.selectedBrowseCollection == nil {
            return "Browse is showing the full dictionary."
        }
        return "Browse is limited to this page; filters still apply."
    }

    private var collectionMenu: some View {
        Menu {
            Button("All Characters") {
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
                Section("Pages") {
                    ForEach(store.allCollections) { collection in
                        Button(collection.name) {
                            store.selectBrowseCollection(id: collection.id)
                        }
                    }
                }
            }
        } label: {
            Label("Page", systemImage: "rectangle.stack")
        }
        .buttonStyle(.bordered)
    }

    private var manualCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Page") {
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
            .navigationTitle("New Page")
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
        case .componentFrequency:
            return "Components (\(store.gridFilteredComponentCount))"
        case .characterFrequency:
            return "All (\(store.gridFilteredAllCount))"
        }
    }

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
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
