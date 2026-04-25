import SwiftUI

struct CharacterDetailView: View {
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    let item: ComponentItem
    @State private var showPhraseTable = false
    private let visiblePhraseRows = 6

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
    private var copyHintLabel: some View {
        HStack(spacing: 4) {
            Text(isRunningOnMac ? "Right-click" : "Long-press")
            Image(systemName: "doc.on.doc")
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if sizeClass == .compact {
                        header
                    }

                    if sizeClass != .compact {
                        HStack(spacing: 8) {
                            editCharacterButton
                            phraseTableButton {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showPhraseTable.toggle()
                                }
                                if showPhraseTable {
                                    store.refreshPhrases()
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            proxy.scrollTo("phraseTableSection", anchor: .top)
                                        }
                                    }
                                }
                            }
                        }
                    }

                    // Quick explainer for how to use Components Explorer
                    if store.showComponentHelp {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Components Explorer")
                                .font(ResponsiveFont.subheadline.bold())
                            Text("Link characters through a shared component: start from a familiar character, tap a component to pivot, view characters built with that part, and keep pivoting until you find the one you need.")
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                            Text("Tap any character to preview. Numbers in boxes show how many characters contain that part.")
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    lineageSection
                    if sizeClass != .compact && showPhraseTable {
                        phrasesSection
                            .id("phraseTableSection")
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .toolbar {
            Button {
                store.toggleFavorite(character: item.character)
            } label: {
                Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
            }
        }
        .onChange(of: store.phraseLength) { _, _ in
            store.refreshPhrases()
        }
        .onChange(of: store.previewCharacter) { _, _ in
            store.refreshPhrases()
        }
        .onAppear { store.refreshPhrases() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sizeClass == .compact {
                // iPhone/Compact Split View: Show consistent comparative animation and info card
                CharacterPreviewHeader(
                    character: item.character,
                    showClearButton: false
                )
                .padding(.bottom, 8)
            } else {
                HStack(alignment: .top, spacing: 16) {
                    // Mac/iPad Regular: Show static large text (consistent with standard dictionary look)
                    Text(item.character)
                        .font(.system(size: 112))
                        .lineLimit(1)
                        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text(item.pinyinText.isEmpty ? "No pinyin" : item.pinyinText)
                            .font(ResponsiveFont.title2)
                            .foregroundStyle(.secondary)
                        Text(item.definition.isEmpty ? "No definition" : item.definition)
                            .font(ResponsiveFont.title3)
                        let allVariants = store.allVariants(for: item.character)
                        if !allVariants.isEmpty {
                            HStack(spacing: 8) {
                                ForEach(allVariants, id: \.character) { v in
                                    Button {
                                        store.select(character: v.character)
                                        store.preview(character: v.character)
                                    } label: {
                                        Text("Variant: \(v.character)")
                                            .font(ResponsiveFont.subheadline)
                                    }
                                    .buttonStyle(.bordered)
                                }
                            }
                        }
                    }
                    Spacer(minLength: 0)
                }
            }
        }
    }

    private var lineageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            lineageControls
            VStack(alignment: .leading, spacing: 6) {
                // Instruction lines now consolidated above; keep this space minimal.
            }
            .font(ResponsiveFont.subheadline) // Increased from caption2
            .foregroundStyle(.tertiary)

            if !store.lineageParents.isEmpty {
                lineageStrip(title: "Components (How it's built)", items: store.lineageParents)
            }

            lineageStrip(title: "Derivatives", items: store.pagedLineageDerivatives)
            
            if entitlement.requiresPro(.lineage) && store.sortedLineageDerivatives.count > 20 {
                Button {
                    store.showPaywall(for: .lineage)
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Show all \(store.sortedLineageDerivatives.count) derivatives")
                    }
                    .font(ResponsiveFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private var phrasesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Picker("Length", selection: $store.phraseLength) {
                    Text("2-char").tag(2)
                    Text("3-char").tag(3)
                    Text("4-char").tag(4)
                }
                .font(ResponsiveFont.subheadline)
                .pickerStyle(.segmented)
                .frame(maxWidth: 280)
                Spacer()
            }

            copyHintLabel

            if store.phrases.isEmpty {
                Text("No phrases found.")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(store.phrases, id: \.id) { phrase in
                                phraseRow(phrase: phrase)
                                Divider()
                            }
                        }
                    }
                    .frame(height: phraseViewportHeight)
                }
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
    }

    private func metaChip(_ value: String) -> some View {
        Text(value)
            .font(ResponsiveFont.subheadline)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.tertiarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func lineageStrip(title: String, items: [ComponentItem]) -> some View {
        let columns: [GridItem] = {
            #if targetEnvironment(macCatalyst)
            return Array(repeating: GridItem(.flexible(), spacing: 6), count: 15)
            #else
            return Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
            #endif
        }()
        
        let fontSize: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 48
            #else
            return 24
            #endif
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.replacingOccurrences(of: " (How it's built)", with: ""))
                    .font(ResponsiveFont.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if title.contains("Components") {
                    Button {
                        store.showComponentHelp = false
                    } label: {
                        Label("Components Explorer", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(ResponsiveFont.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(sizeClass == .compact ? .small : .regular)
                }
            }
            
            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items, id: \.character) { linkedItem in
                    VStack(spacing: 0) {
                        // 1. Character Area
                        VStack(spacing: 2) {
                            Text(linkedItem.character)
                                .font(.system(size: fontSize))
                                .copyCharacterContextMenu(linkedItem.character, pinyin: linkedItem.pinyinText)
                            Text(linkedItem.pinyinText.isEmpty ? " " : linkedItem.pinyinText)
                                .font(.system(size: 12, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 8)
                        .foregroundStyle(Color.primary)
                        
                        // 2. Usage Footer
                        if linkedItem.usageCount > 0 {
                            Text("\(linkedItem.usageCount.formatted(.number.grouping(.never)))")
                                .font(.system(size: 13, weight: .black)) // Larger & Bolder
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 2)
                                .background(Color.secondary.opacity(0.15))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .background(Color.secondary.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
                    )
                    .contentShape(RoundedRectangle(cornerRadius: 8))
                    .onTapGesture {
                        store.showComponentHelp = false
                        store.preview(character: linkedItem.character)
                    }
                    .simultaneousGesture(
                        TapGesture(count: 2).onEnded {
                            store.select(character: linkedItem.character)
                        }
                    )
                }
            }
        }
        .padding(.vertical, 4)
    }

    private var lineageControls: some View {
        HStack {
            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }

            Spacer(minLength: 8)

            Button("Prev") { store.previousLineagePage() }
                .font(ResponsiveFont.subheadline)
                .buttonStyle(.bordered)
                .disabled(store.lineagePage == 0)
            Text("Batch \(store.lineagePage + 1)/\(store.lineagePageCount)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Button("Next") { store.nextLineagePage() }
                .font(ResponsiveFont.subheadline)
                .buttonStyle(.bordered)
                .disabled(store.lineagePage + 1 >= store.lineagePageCount)
        }
    }

    private func phraseRow(phrase: PhraseItem) -> some View {
        let characterColumnWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 150
            #else
            return 120
            #endif
        }()

        return HStack(alignment: .top, spacing: 8) { // Narrowed from 12
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
            .frame(width: characterColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: phraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .phraseContextMenu(phrase)
    }

    private func phraseTableButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: showPhraseTable ? "text.justify" : "text.justify.left")
                Text(showPhraseTable ? "Hide Phrase Table" : "Show Phrase Table")
                Spacer()
                Text("\(store.phraseLength)-char")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(ResponsiveFont.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var editCharacterButton: some View {
        Button {
            store.openQuickCharacterEditor(item.character)
        } label: {
            Label(store.characterNotesActionTitle(for: item.character), systemImage: "square.and.pencil")
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var phraseRowHeight: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return 76
        #endif
    }

    private var phraseViewportHeight: CGFloat {
        (phraseRowHeight * CGFloat(visiblePhraseRows)) + 5
    }

    private func primaryMeaning(_ meanings: String) -> String {
        meanings
            .components(separatedBy: ";")
            .first?
            .trimmingCharacters(in: .whitespacesAndNewlines) ?? meanings
    }
    
    private func tierChip(for tier: Int) -> some View {
        Text("Tier \(tier)")
            .font(ResponsiveFont.footnote.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tierColor(for: tier))
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }
    
    private func tierColor(for tier: Int) -> Color {
        switch tier {
        case 1: return Color.green
        case 2: return Color.blue
        case 3: return Color.orange
        case 4: return Color.purple
        default: return Color.gray
        }
    }
}

struct ComponentsExplorerShell: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var seed: String = ""
    @State private var showRootFilters = false
    var seedOverride: String?

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
    private var gridInteractionHintRow: some View {
        HStack(spacing: 10) {
            hintChip(icon: "cursorarrow", text: isRunningOnMac ? "Click Preview" : "Tap Preview")
            hintChip(icon: "cursorarrow.click.2", text: isRunningOnMac ? "Double-click keeps in memory" : "Double-tap keeps in memory")
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

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    private var hasRootContext: Bool {
        seedOverride != nil || store.previewCharacter != nil || store.selectedCharacter != nil || !seed.isEmpty
    }

    var body: some View {
        #if targetEnvironment(macCatalyst)
        let isPhone = false
        #else
        let isPhone = UIDevice.current.userInterfaceIdiom == .phone
        #endif

        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    Color.clear.frame(height: 0).id("rootsTop")

                    // Active character header (phones only; sidebar handles iPad/Mac)
                    if isPhone,
                       hasRootContext,
                       let current = store.previewCharacter,
                       store.item(for: current) != nil {
                        standardPhoneCharacterPreview(
                            character: current,
                            selectedCharacter: store.selectedCharacter,
                            onClear: { store.previewCharacter = nil }
                        )
                        .padding(.bottom, 8)
                    }

                    HStack(alignment: .center, spacing: 12) {
                        CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }

                        Button {
                            showRootFilters = true
                        } label: {
                            Label(rootFilterButtonTitle, systemImage: activeRootFilterCount > 0 ? "line.3.horizontal.decrease.circle.fill" : "line.3.horizontal.decrease.circle")
                                .font(ResponsiveFont.subheadline.weight(.semibold))
                                .padding(.horizontal, 12)
                                .padding(.vertical, 10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                        .buttonStyle(.plain)

                        Spacer()
                    }
                    .padding(.bottom, 4)

                    gridInteractionHintRow

                    if store.showComponentHelp {
                        // Inline explainer inside the explorer itself
                        VStack(alignment: .leading, spacing: 4) {
                            Text("How to use Components Explorer")
                                .font(ResponsiveFont.subheadline.bold())
                            Text("Link characters through a shared component: start from a familiar character, tap a component to pivot, view characters built with that part, and keep pivoting until you find the one you need.")
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    if hasRootContext {
                        if !store.sharedPeersByComponent.isEmpty {
                            ForEach(Array(store.sharedPeersByComponent.keys).sorted(), id: \.self) { comp in
                                let compItem = store.item(for: comp)
                                let peers = store.sharedPeersByComponent[comp] ?? []
                                let rowItems: [ComponentItem] = {
                                    guard let compItem else { return peers }
                                    return ([compItem] + peers).reduce(into: []) { partial, item in
                                        if !partial.contains(where: { $0.character == item.character }) {
                                            partial.append(item)
                                        }
                                    }
                                }()
                                VStack(alignment: .leading, spacing: 8) {
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(componentSectionTitle(for: comp, item: compItem))
                                            .font(ResponsiveFont.headline)
                                        Text("Sorted by how often this component appears in other characters.")
                                            .font(ResponsiveFont.caption)
                                            .foregroundStyle(.secondary)
                                    }

                                    #if targetEnvironment(macCatalyst)
                                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: 8)], spacing: 8) {
                                        ForEach(rowItems, id: \.character) { item in
                                            branchRow(item)
                                        }
                                    }
                                    #else
                                    ScrollView(.horizontal, showsIndicators: false) {
                                        HStack(spacing: 8) {
                                            ForEach(rowItems, id: \.character) { item in
                                                branchRow(item)
                                            }
                                        }
                                    }
                                    #endif
                                }
                                .padding(10)
                                .background(Color(.secondarySystemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                        }

                        VStack(alignment: .leading, spacing: 8) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Characters containing \(seed) (\(store.rootDerivativesTotal))")
                                    .font(ResponsiveFont.headline)
                                Text("Sorted by popular usage.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)
                            }
                            if store.rootDerivatives.isEmpty {
                                Text("No derivatives found for this character.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)
                            } else {
                                ScrollView(.horizontal, showsIndicators: false) {
                                    LazyHStack(spacing: 8) {
                                        ForEach(store.rootDerivatives, id: \.character) { item in
                                            branchRow(item)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        let initial = store.rootInitialGridItems()
                        initialRootGrid(items: initial.items, total: initial.total)
                    }
                }
                .padding()
            }
            .onChange(of: seed) { _, _ in
                withAnimation { proxy.scrollTo("rootsTop", anchor: .top) }
            }
            .onChange(of: store.previewCharacter) { _, _ in
                withAnimation { proxy.scrollTo("rootsTop", anchor: .top) }
            }
            .onChange(of: store.selectedCharacter) { _, _ in
                withAnimation { proxy.scrollTo("rootsTop", anchor: .top) }
            }
        }
        .navigationTitle("Roots")
        .onAppear {
            let start = seedOverride ?? store.selectedCharacter ?? store.previewCharacter
            syncSeed(with: start, resetHistory: true)
        }
        .onChange(of: store.scriptFilter) { _, _ in
            reloadRootContextIfNeeded()
        }
        .onChange(of: store.rootMinStroke) { _, _ in
            reloadRootContextIfNeeded()
        }
        .onChange(of: store.rootMaxStroke) { _, _ in
            reloadRootContextIfNeeded()
        }
        .onChange(of: store.rootRadicalFilter) { _, _ in
            reloadRootContextIfNeeded()
        }
        .onChange(of: store.rootStructureFilter) { _, _ in
            reloadRootContextIfNeeded()
        }
        // Keep in sync with sidebar selection on iPad/Mac (not needed on iPhone)
        #if targetEnvironment(macCatalyst)
        .onChange(of: store.selectedCharacter) { _, newValue in
            syncSeed(with: newValue, resetHistory: false)
        }
        #else
        .onChange(of: store.selectedCharacter) { _, newValue in
            if UIDevice.current.userInterfaceIdiom != .phone {
                syncSeed(with: newValue, resetHistory: false)
            }
        }
        #endif
        .sheet(isPresented: $showRootFilters) {
            rootFiltersSheet
        }
    }

    private var activeRootFilterCount: Int {
        var count = 0
        if store.rootMinStroke > 0 || store.rootMaxStroke < 30 { count += 1 }
        if store.rootRadicalFilter != "none" { count += 1 }
        if store.rootStructureFilter != "none" { count += 1 }
        return count
    }

    private var rootFilterButtonTitle: String {
        activeRootFilterCount > 0 ? "Filters (\(activeRootFilterCount))" : "Filters"
    }

    private var rootFiltersSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Strokes")
                            .font(ResponsiveFont.caption.bold())
                            .foregroundStyle(.secondary)
                        StrokeRangeSlider(minValue: $store.rootMinStroke, maxValue: $store.rootMaxStroke)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        rootRadicalPicker
                        rootStructurePicker
                    }
                }
                .padding()
            }
            .navigationTitle("Roots Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if activeRootFilterCount > 0 {
                        Button("Reset") {
                            store.rootMinStroke = 0
                            store.rootMaxStroke = 30
                            store.rootRadicalFilter = "none"
                            store.rootStructureFilter = "none"
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        showRootFilters = false
                    }
                }
            }
            .presentationDetents(sizeClass == .compact ? [.medium, .large] : [.large])
        }
    }

    private var rootRadicalPicker: some View {
        HStack(spacing: 8) {
            Text("Radical")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Radical", selection: $store.rootRadicalFilter) {
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

    private var rootStructurePicker: some View {
        HStack(spacing: 8) {
            Text("Structure")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Structure", selection: $store.rootStructureFilter) {
                ForEach(store.availableStructureFilters, id: \.self) { structKey in
                    Text(structKey).tag(structKey)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func initialRootGrid(items: [ComponentItem], total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("All characters (\(total))")
                    .font(ResponsiveFont.headline)
                Text("Choose a character to explore its roots.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("No characters match the current filters.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: 8)], spacing: 8) {
                    ForEach(items, id: \.character) { item in
                        initialRootCell(item)
                    }
                }
            }
        }
    }

    private func initialRootCell(_ item: ComponentItem) -> some View {
        VStack(spacing: 4) {
            Text(item.character)
                .font(.system(size: 30, weight: .bold))
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
            Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                .font(ResponsiveFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("\(item.usageCount)")
                .font(ResponsiveFont.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5)
        )
        .onTapGesture {
            startRootExploration(with: item.character, remember: false)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                startRootExploration(with: item.character, remember: true)
            }
        )
    }

    private var emptyStateCard: some View {
        VStack(spacing: 8) {
            Image(systemName: "tree")
                .font(.system(size: 44, weight: .light))
                .foregroundStyle(.secondary)
            Text("No Character")
                .font(ResponsiveFont.title3.bold())
            Text("Choose a character from Search or Browse to explore Roots.")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .padding()
        .frame(maxWidth: .infinity, alignment: .center)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .padding()
    }

    private func lineageRow(_ item: ComponentItem) -> some View {
        let charSize: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 48
            #else
            return 28
            #endif
        }()
        let charWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 54
            #else
            return 36
            #endif
        }()

        return HStack {
            Text(item.character)
                .font(.system(size: charSize))
                .frame(width: charWidth)
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
        VStack(alignment: .leading, spacing: 2) {
            Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.secondary)
                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(ResponsiveFont.body)
                    .lineLimit(1)
            }
            Spacer()
            Text("U\(item.usageCount)")
                .font(ResponsiveFont.caption)
                .padding(.horizontal, 6)
                .padding(.vertical, 3)
                .background(Color(.secondarySystemBackground))
                .clipShape(Capsule())
        }
    }

    private func branchRow(_ item: ComponentItem) -> some View {
        let isIPad: Bool = {
            #if targetEnvironment(macCatalyst)
            return false
            #else
            return UIDevice.current.userInterfaceIdiom == .pad
            #endif
        }()

        let pinyinFont: Font = isIPad
            ? .system(size: 16, weight: .semibold)
            : ResponsiveFont.caption
        let usageFont: Font = isIPad
            ? .system(size: 13, weight: .semibold)
            : ResponsiveFont.caption2

        return VStack(spacing: 4) {
            Text(item.character)
                .font(.system(size: 30, weight: .bold))
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
            Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                .font(pinyinFont)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("\(item.usageCount)")
                .font(usageFont)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8).stroke(Color(.separator), lineWidth: 0.5)
        )
        .onTapGesture {
            pivot(to: item.character, selectAfter: false)
        }
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                pivot(to: item.character, selectAfter: true)
            }
        )
    }

    private func pivot(to character: String, selectAfter: Bool) {
        if selectAfter {
            seed = character
            store.pushRootBreadcrumb(character)
            store.select(character: character)
            store.loadSharedComponentPeers(for: character)
            store.loadSharedPeersByComponent(for: character)
            store.loadRootDerivatives(for: character)
        } else {
            // Preview only; do not change shared data or Remembered state.
            store.preview(character: character)
        }
        store.showComponentHelp = false
    }

    private func startRootExploration(with character: String, remember: Bool) {
        seed = character
        store.preview(character: character)
        if remember {
            store.pushRootBreadcrumb(character)
            store.select(character: character)
        }
        store.loadSharedComponentPeers(for: character)
        store.loadSharedPeersByComponent(for: character)
        store.loadRootDerivatives(for: character)
        store.showComponentHelp = false
    }

    private func reloadRootContextIfNeeded() {
        let start = seed
        guard !start.isEmpty else { return }
        store.loadSharedComponentPeers(for: start)
        store.loadSharedPeersByComponent(for: start)
        store.loadRootDerivatives(for: start)
    }

    private func syncSeed(with character: String?, resetHistory: Bool = false) {
        guard let character, character != seed else { return }
        if resetHistory {
            store.resetRootBreadcrumb(to: character)
        } else {
            store.pushRootBreadcrumb(character)
        }
        seed = character
        store.loadSharedComponentPeers(for: character)
        store.loadSharedPeersByComponent(for: character)
        store.loadRootDerivatives(for: character)
        store.showComponentHelp = false
    }

    private func stepBreadcrumb(_ delta: Int) {
        guard let target = store.stepRootBreadcrumb(by: delta) else { return }
        seed = target
        store.select(character: target)
        store.loadSharedComponentPeers(for: target)
        store.loadSharedPeersByComponent(for: target)
        store.loadRootDerivatives(for: target)
    }

    private func jumpToBreadcrumb(index: Int) {
        let delta = index - store.rootBreadcrumbIndex
        stepBreadcrumb(delta)
    }

    private func componentSectionTitle(for component: String, item: ComponentItem?) -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Characters containing this component" }
        return "Characters containing \(item?.character ?? trimmed)"
    }

}
