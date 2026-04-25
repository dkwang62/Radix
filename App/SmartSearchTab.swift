import SwiftUI

struct SmartSearchTab: View {
    @EnvironmentObject private var store: RadixStore
    @FocusState private var isSearchFocused: Bool
    @State private var localQuery: String = ""
    @State private var searchGridPage: Int = 0
    @State private var searchPreviewCharacter: String? = nil
    @State private var searchDetailPreviewCharacter: String? = nil
    @State private var searchDrilldownPhrases: [PhraseItem] = []
    @State private var showAppleSetupGuide = false
    @State private var showAppleStrokeHelp = false
    @State private var searchCardVariantIndex: Int = 0

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

    private func hintChip(icon: String, text: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
            Text(text)
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    private func runSearch(_ query: String) {
        searchGridPage = 0
        searchPreviewCharacter = nil
        searchDetailPreviewCharacter = nil
        searchDrilldownPhrases = []
        store.performSearch(customQuery: query)
    }

    private func syncSearchPreviewFromStore() {
        guard store.hasPerformedSearch, searchPreviewCharacter == nil else { return }
        searchDetailPreviewCharacter = store.previewCharacter
    }

    private func setSearchDrilldownAnchor(_ character: String) {
        searchPreviewCharacter = character
        searchDetailPreviewCharacter = character
        searchDrilldownPhrases = store.phraseMatches(for: character, length: store.phraseLength)
    }

    private var initialPhraseMatchesForSelectedLength: [PhraseItem] {
        store.filteredSmartPhraseResults.filter { $0.word.count == store.phraseLength }
    }

    @ViewBuilder
    private var searchHistoryMenu: some View {
        if !store.searchHistory.isEmpty {
            Menu {
                ForEach(Array(store.searchHistory.enumerated().reversed()), id: \.offset) { _, query in
                    Button(query) {
                        localQuery = query
                        runSearch(query)
                        isSearchFocused = false
                    }
                }

                Divider()

                Button(role: .destructive) {
                    store.clearSearchHistory()
                } label: {
                    Label("Clear History", systemImage: "trash")
                }
            } label: {
                Image(systemName: "clock.arrow.circlepath")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .frame(width: 28, height: 28)
                    .contentShape(Rectangle())
            }
            .accessibilityLabel("Search History")
        }
    }

    private var phraseLengthPicker: some View {
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
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    Color.clear.frame(height: 0).id("searchTop")
                VStack(alignment: .center, spacing: 15) {
                    HStack(spacing: 12) {
                        HStack {
                            searchHistoryMenu

                            TextField("See examples", text: $localQuery)
                                .font(ResponsiveFont.body)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .focused($isSearchFocused)
                                .submitLabel(.search)
                                .onSubmit {
                                    runSearch(localQuery)
                                }
                            
                            if !localQuery.isEmpty {
                                Button {
                                    localQuery = ""
                                    searchGridPage = 0
                                    searchPreviewCharacter = nil
                                    searchDetailPreviewCharacter = nil
                                    searchDrilldownPhrases = []
                                    store.clearSearch()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(ResponsiveFont.body)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(12)
                        .background(Color(.secondarySystemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(isSearchFocused ? Color.accentColor : Color.clear, lineWidth: 2)
                        )
                        .shadow(color: isSearchFocused ? Color.accentColor.opacity(0.2) : Color.clear, radius: 4)
                        
                    Button {
                        runSearch(localQuery)
                        isSearchFocused = false
                    } label: {
                        Text("Search")
                            .font(ResponsiveFont.headline)
                            .padding(.horizontal, 20)
                            .padding(.vertical, 12)
                                .background(Color.accentColor)
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                        }
                    }
                    .padding(.top, 10)

                }
                .padding(.vertical, isRunningOnMac ? 30 : 16)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))

                if store.hasPerformedSearch {
                    VStack(alignment: .leading, spacing: 15) {
                        // Preview/Info card for current previewed/selected character (phones only; sidebar shows it on iPad/Mac)
                        #if !targetEnvironment(macCatalyst)
                        if UIDevice.current.userInterfaceIdiom == .phone,
                           let current = searchDetailPreviewCharacter ?? searchPreviewCharacter,
                           store.item(for: current) != nil {
                            standardPhoneCharacterPreview(
                                character: current,
                                selectedCharacter: store.selectedCharacter,
                                onClear: {
                                    searchPreviewCharacter = nil
                                    searchDetailPreviewCharacter = nil
                                    store.previewCharacter = nil
                                }
                            )
                        }
                        #endif
                        HStack {
                            Text("\(store.filteredResults.count) characters for \"\(store.lastSearchQuery)\"")
                                .font(ResponsiveFont.title3)
                            Spacer()
                            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }
                            Button("Clear Results") {
                                    searchGridPage = 0
                                    searchPreviewCharacter = nil
                                    searchDetailPreviewCharacter = nil
                                    searchDrilldownPhrases = []
                                    store.clearSearch()
                            }
                            .font(ResponsiveFont.caption)
                        }

                        gridInteractionHintRow

                        SmartResultsGrid(
                            items: store.filteredResults,
                            currentPage: $searchGridPage,
                            onPreview: { character in
                                setSearchDrilldownAnchor(character)
                            },
                            onSelect: { withAnimation { proxy.scrollTo("searchTop", anchor: .top) } }
                        )

                        if let current = searchPreviewCharacter,
                           store.item(for: current) != nil {
                            VStack(alignment: .leading, spacing: 10) {
                                Text("Phrase Drilldown")
                                    .font(ResponsiveFont.headline)
                                Text("Preview a character from the grid to update this phrase layer. Characters inside phrases only update the preview card.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)

                                phraseLengthPicker

                                if searchDrilldownPhrases.isEmpty {
                                    Text("No \(store.phraseLength)-character phrase matches are available yet for \(current).")
                                        .font(ResponsiveFont.caption)
                                        .foregroundStyle(.secondary)
                                        .padding(10)
                                        .frame(maxWidth: .infinity, alignment: .leading)
                                        .background(Color(.secondarySystemBackground))
                                        .clipShape(RoundedRectangle(cornerRadius: 10))
                                } else {
                                    LazyVStack(alignment: .leading, spacing: 8) {
                                        ForEach(searchDrilldownPhrases.prefix(30)) { phrase in
                                            VStack(alignment: .leading, spacing: 4) {
                                                Text(phrase.word)
                                                    .font(ResponsiveFont.title3)
                                                    .phraseContextMenu(phrase)
                                                if !phrase.pinyin.isEmpty {
                                                    Text(phrase.pinyin)
                                                        .font(ResponsiveFont.subheadline)
                                                        .foregroundStyle(.secondary)
                                                }
                                                if !phrase.meanings.isEmpty {
                                                    Text(phrase.meanings)
                                                        .font(ResponsiveFont.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                }
                                                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                                    Text(phrase.notes)
                                                        .font(ResponsiveFont.caption)
                                                        .foregroundStyle(.secondary)
                                                        .lineLimit(2)
                                                }

                                                let chars = phrase.word.map(String.init).filter { store.item(for: $0) != nil }
                                                if !chars.isEmpty {
                                                    ScrollView(.horizontal, showsIndicators: false) {
                                                        HStack(spacing: 6) {
                                                            ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                                                                Button(ch) {
                                                                    searchDetailPreviewCharacter = ch
                                                                    store.preview(character: ch)
                                                                    withAnimation { proxy.scrollTo("searchTop", anchor: .top) }
                                                                }
                                                                .copyCharacterContextMenu(ch, pinyin: store.item(for: ch)?.pinyinText)
                                                                .buttonStyle(.bordered)
                                                                .controlSize(.small)
                                                                .font(ResponsiveFont.body)
                                                            }
                                                        }
                                                    }
                                                    .padding(.top, 2)
                                                }
                                            }
                                            .padding(10)
                                            .frame(maxWidth: .infinity, alignment: .leading)
                                            .background(Color(.secondarySystemBackground))
                                            .clipShape(RoundedRectangle(cornerRadius: 10))
                                        }
                                    }
                                }
                            }
                        }

                        if searchPreviewCharacter == nil && !store.filteredSmartPhraseResults.isEmpty {
                            Divider().padding(.vertical, 8)
                            Text("Phrase Matches")
                                .font(ResponsiveFont.headline)
                            phraseLengthPicker
                            if initialPhraseMatchesForSelectedLength.isEmpty {
                                Text("No \(store.phraseLength)-character phrase matches for this search.")
                                    .font(ResponsiveFont.caption)
                                    .foregroundStyle(.secondary)
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            LazyVStack(alignment: .leading, spacing: 8) {
                                ForEach(initialPhraseMatchesForSelectedLength.prefix(50)) { phrase in
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(phrase.word)
                                            .font(ResponsiveFont.title3)
                                            .phraseContextMenu(phrase)
                                        if !phrase.pinyin.isEmpty {
                                            Text(phrase.pinyin)
                                                .font(ResponsiveFont.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                        if !phrase.meanings.isEmpty {
                                            Text(phrase.meanings)
                                                .font(ResponsiveFont.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                        if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                                            Text(phrase.notes)
                                                .font(ResponsiveFont.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }

                                        let chars = phrase.word.map(String.init).filter { store.item(for: $0) != nil }
                                        if !chars.isEmpty {
                                            ScrollView(.horizontal, showsIndicators: false) {
                                                HStack(spacing: 6) {
                                                    ForEach(Array(chars.enumerated()), id: \.offset) { _, ch in
                                                        Button(ch) {
                                                            searchDetailPreviewCharacter = ch
                                                            store.preview(character: ch)
                                                            withAnimation { proxy.scrollTo("searchTop", anchor: .top) }
                                                        }
                                                        .copyCharacterContextMenu(ch, pinyin: store.item(for: ch)?.pinyinText)
                                                        .buttonStyle(.bordered)
                                                        .controlSize(.small)
                                                        .font(ResponsiveFont.body)
                                                    }
                                                }
                                            }
                                            .padding(.top, 2)
                                        }
                                    }
                                    .padding(10)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .background(Color(.secondarySystemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 10))
                                }
                            }
                        }
                        
                        if store.filteredResults.isEmpty && store.filteredSmartPhraseResults.isEmpty {
                            ContentUnavailableView.search(text: store.lastSearchQuery)
                        }
                    }
                } else {
                    VStack(spacing: 14) {
                        VStack(alignment: .leading, spacing: 12) {
                            Text("Search by English")
                                .font(ResponsiveFont.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SearchExampleButton(label: "=water ->", query: "水") { _ in
                                    localQuery = "=water"
                                    runSearch("=water")
                                }
                                SearchExampleButton(label: "watery ->", query: "含水") { _ in
                                    localQuery = "watery"
                                    runSearch("watery")
                                }
                            }

                            Text("Search by Pinyin")
                                .font(ResponsiveFont.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SearchExampleButton(label: "shui ->", query: "水") { _ in
                                    localQuery = "shui"
                                    runSearch("shui")
                                }
                                SearchExampleButton(label: "hanshui ->", query: "含水") { _ in
                                    localQuery = "hanshui"
                                    runSearch("hanshui")
                                }
                            }

                            Text("Search by Apple IME Strokes")
                                .font(ResponsiveFont.subheadline)
                                .foregroundStyle(.secondary)
                            HStack(spacing: 8) {
                                SearchExampleButton(label: "ノ丶丶フ丨 ->", query: "含") { _ in
                                    localQuery = "ノ丶丶フ丨"
                                    runSearch("ノ丶丶フ丨")
                                }
                                SearchExampleButton(label: "丨フノ丶 ->", query: "水") { _ in
                                    localQuery = "丨フノ丶"
                                    runSearch("丨フノ丶")
                                }
                            }
                        }
                        .padding(isRunningOnMac ? 20 : 14)
                        .background(Color(.secondarySystemBackground).opacity(0.5))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .frame(maxWidth: {
                            #if targetEnvironment(macCatalyst)
                            return 900
                            #else
                            return 550
                            #endif
                        }())

                        VStack(alignment: .leading, spacing: 12) {
                            DisclosureGroup(isExpanded: $showAppleStrokeHelp) {
                                VStack(alignment: .leading, spacing: 6) {
                                    if isRunningOnMac {
                                        AppleStrokeKeyMap()
                                        AppleStrokeExamplesView()
                                    } else {
                                        AppleStrokeExamplesView(compact: true)
                                    }
                                }
                            } label: {
                                Label("Show IME Chinese Strokes examples", systemImage: "keyboard")
                                    .font(ResponsiveFont.caption.weight(.semibold))
                            }
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)

                            DisclosureGroup(isExpanded: $showAppleSetupGuide) {
                                if isRunningOnMac {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("On Mac")
                                            .font(ResponsiveFont.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("1. Apple menu > System Settings > Keyboard > Text Input > Edit.")
                                        Text("2. Add Chinese, Simplified - Stroke or Chinese, Traditional - Stroke.")
                                        Text("3. Switch to that input source from the menu bar.")
                                        Text("4. Enter the component or character in the search field above.")
                                    }
                                } else {
                                    VStack(alignment: .leading, spacing: 8) {
                                        Text("On iPhone or iPad")
                                            .font(ResponsiveFont.caption.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                        Text("1. Go to Settings > General > Keyboard > Keyboards > Add New Keyboard.")
                                        Text("2. Add Chinese, Simplified, Chinese, Traditional, or Chinese Handwriting.")
                                        Text("3. Return to this app and tap the search field above.")
                                        Text("4. Use Apple’s keyboard candidate bar to enter the component or character.")
                                        Text("If you use a hardware keyboard, you can switch keyboards with Control-Space.")
                                    }
                                }
                            } label: {
                                Label("Show keyboard setup", systemImage: "gearshape")
                                    .font(ResponsiveFont.caption.weight(.semibold))
                            }
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                        }
                        .padding(isRunningOnMac ? 14 : 10)
                        .frame(maxWidth: isRunningOnMac ? 760 : .infinity)
                        .background(Color(.secondarySystemBackground).opacity(0.55))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, isRunningOnMac ? 40 : 12)
                }
            }
            .padding(.horizontal)
            .onChange(of: store.previewCharacter) { _, _ in
                syncSearchPreviewFromStore()
            }
            .onChange(of: store.selectedCharacter) { _, _ in
                syncSearchPreviewFromStore()
            }
            .onChange(of: store.query) { _, newValue in
                localQuery = newValue
            }
            .onChange(of: store.route) { _, newRoute in
                if newRoute != .search {
                    searchPreviewCharacter = nil
                    searchDetailPreviewCharacter = nil
                    searchDrilldownPhrases = []
                }
            }
            .onChange(of: store.homeTab) { _, newTab in
                if newTab != .smart {
                    searchPreviewCharacter = nil
                    searchDetailPreviewCharacter = nil
                    searchDrilldownPhrases = []
                }
            }
            .onChange(of: store.phraseLength) { _, _ in
                if let current = searchPreviewCharacter {
                    searchDrilldownPhrases = store.phraseMatches(for: current, length: store.phraseLength)
                }
            }
            .onAppear {
                // Keep Search clean on tab entry; show preview only after explicit tap.
                searchPreviewCharacter = nil
                searchDetailPreviewCharacter = nil
                searchDrilldownPhrases = []
                localQuery = store.query
            }
        }
    }
}
}
