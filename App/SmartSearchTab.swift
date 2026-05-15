import SwiftUI

struct SmartSearchTab: View {
    @EnvironmentObject var store: RadixStore
    @FocusState var isSearchFocused: Bool
    @State var localQuery: String = ""
    @State var searchGridPage: Int = 0
    @State var searchPreviewCharacter: String?
    @State var searchDetailPreviewCharacter: String?
    @State var searchDrilldownPhrases: [PhraseItem] = []
    @State var selectedPhrase: PhraseItem?
    @State var showAppleSetupGuide = false
    @State var showAppleStrokeHelp = false
    @State var searchCardVariantIndex: Int = 0

    var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                if isPhoneSearchPreviewActive {
                    VStack(alignment: .leading, spacing: 10) {
                        Color.clear.frame(height: 0).id("searchTop")
                        phoneSearchPreview(proxy: proxy)
                    }
                    .padding(.horizontal)
                } else {
                    VStack(alignment: .leading, spacing: 20) {
                        Color.clear.frame(height: 0).id("searchTop")
                        searchHeader

                        if store.hasPerformedSearch {
                            searchResults(proxy: proxy)
                        } else {
                            searchExamplesAndHelp
                        }
                    }
                    .padding(.horizontal)
                }
            }
            .onChange(of: store.previewCharacter) { _, _ in
                syncSearchPreviewFromStore()
            }
            .onChange(of: store.query) { _, newValue in
                localQuery = newValue
            }
            .onChange(of: store.route) { _, newRoute in
                if newRoute != .search {
                    resetSearchPreviewState()
                }
            }
            .onChange(of: store.homeTab) { _, newTab in
                if newTab != .smart {
                    resetSearchPreviewState()
                }
            }
            .onChange(of: store.phraseLength) { _, _ in
                if let current = searchPreviewCharacter {
                    searchDrilldownPhrases = store.phraseMatches(for: current, length: store.phraseLength)
                }
            }
            .onAppear {
                resetSearchPreviewState()
                localQuery = store.query
            }
            .sheet(item: phonePhraseSheetBinding) { phrase in
                NavigationStack {
                    PhraseInfoCard(phrase: phrase, onDone: finishPhraseLookup)
                        .environmentObject(store)
                        .padding()
                        .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
        }
    }

    func runSearch(_ query: String) {
        searchGridPage = 0
        resetSearchPreviewState()
        store.performSearch(customQuery: query)
    }

    func clearSearchResults() {
        searchGridPage = 0
        resetSearchPreviewState()
        store.clearSearch()
    }

    func resetSearchPreviewState() {
        searchPreviewCharacter = nil
        searchDetailPreviewCharacter = nil
        searchDrilldownPhrases = []
        selectedPhrase = nil
    }
}
