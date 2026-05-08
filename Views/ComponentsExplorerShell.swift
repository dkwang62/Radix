import SwiftUI

struct ComponentsExplorerShell: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var seed: String = ""
    @State private var showRootFilters = false
    @State private var expandedComponents: Set<String> = []
    @State private var derivativesExpanded: Bool = false
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
            hintChip(icon: "bookmark", text: "Preview adds to 🕘")
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
        seedOverride != nil || store.previewCharacter != nil || !seed.isEmpty
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

                    if isPhone,
                       hasRootContext,
                       let current = store.previewCharacter,
                       store.item(for: current) != nil {
                        standardPhoneCharacterPreview(
                            character: current,
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
                        derivativesSection
                        sharedPeersSections
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
        }
        .navigationTitle("Components")
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                if store.rootsReturnContext != nil {
                    Button {
                        store.returnFromRoots()
                    } label: {
                        Label(store.rootsReturnButtonTitle, systemImage: "chevron.backward")
                    }
                }
            }
        }
        .onAppear {
            let start = seedOverride ?? store.previewCharacter
            syncSeed(with: start, resetHistory: true)
        }
        .onDisappear {
            expandedComponents = []
            derivativesExpanded = false
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
        #if targetEnvironment(macCatalyst)
        .onChange(of: store.previewCharacter) { _, newValue in
            syncSeed(with: newValue, resetHistory: false)
        }
        #else
        .onChange(of: store.previewCharacter) { _, newValue in
            if UIDevice.current.userInterfaceIdiom != .phone {
                syncSeed(with: newValue, resetHistory: false)
            }
        }
        #endif
        .sheet(isPresented: $showRootFilters) {
            rootFiltersSheet
        }
    }

    private var derivativesSection: some View {
        VStack(alignment: .leading, spacing: derivativesExpanded ? 8 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    derivativesExpanded.toggle()
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Characters containing \(seed) (\(store.rootDerivativesTotal))")
                            .font(ResponsiveFont.headline)
                        if derivativesExpanded {
                            Text("Sorted by popular usage.")
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Spacer()
                    Image(systemName: derivativesExpanded ? "chevron.up" : "chevron.down")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if derivativesExpanded {
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
        }
        .padding(10)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    @ViewBuilder
    private var sharedPeersSections: some View {
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
                let isExpanded = expandedComponents.contains(comp)
                VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
                    Button {
                        withAnimation(.easeInOut(duration: 0.2)) {
                            if isExpanded {
                                expandedComponents.remove(comp)
                            } else {
                                expandedComponents.insert(comp)
                            }
                        }
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(componentSectionTitle(for: comp, item: compItem) + " (\(rowItems.count))")
                                    .font(ResponsiveFont.headline)
                                if isExpanded {
                                    Text("Sorted by how often this component appears in other characters.")
                                        .font(ResponsiveFont.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                            Spacer()
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(ResponsiveFont.caption.bold())
                                .foregroundStyle(.secondary)
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .contentShape(Rectangle())
                    }
                    .buttonStyle(.plain)

                    if isExpanded {
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
                }
                .padding(10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
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
            .navigationTitle("Component Filters")
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
                    Button {
                        showRootFilters = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
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
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            startRootExploration(with: item.character, remember: false)
        }
        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
    }

    private func branchRow(_ item: ComponentItem) -> some View {
        ComponentCharacterTile(item: item) {
            pivot(to: item.character, selectAfter: false)
        }
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
