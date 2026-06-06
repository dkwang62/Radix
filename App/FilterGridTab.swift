import SwiftUI
import UIKit

struct FilterGridTab: View {
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @Environment(\.openURL) var openURL
    @AppStorage("hasShownBrowseInteractionHintRowV1") var hasShownBrowseInteractionHintRow = false
    @AppStorage("browseImageScriptMode") var browseImageScriptMode = "simplified"
    @AppStorage("browsePageSortOrder") var browsePageSortRawValue = PageCollectionSortOrder.lastViewed.rawValue
    @AppStorage("radixFreeCameraScanCount") var freePageUseCount = 0
    @State var showBrowseFilters = false
    @State var showManualCollectionSheet = false
    @State var showBrowseSource = false
    @State var showBrowseInteractionHint = false
    @State var manualCollectionName = ""
    @State var manualCollectionText = ""
    @State var pendingDeleteCollection: CharacterCollection?
    @State var editingCollection: CharacterCollection?
    @State var editingCollectionName = ""
    @State var editingCollectionText = ""
    @State var collectionEditorError: String?
    @State var translationReportCollection: CharacterCollection?
    @State var translationReportDraft = ""
    @State var phraseExtractionCollection: CharacterCollection?
    @State var pagePhraseListCollection: CharacterCollection?
    @State var phraseExtractionOutput = ""
    @State var imageActionMessage: String?
    @State var isRunningImageAction = false
    @State var lastTappedImageOffset: Int?

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

    var isPhoneBrowseLayout: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var isPhoneBrowsePreviewActive: Bool {
        isPhoneBrowseLayout && (store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil)
    }

    var browseGridLayout: BrowseGridLayout {
        .current
    }

    @ViewBuilder
    var browseInteractionHintRow: some View {
        InteractionHintRow(
            previewText: isRunningOnMac ? "Click to preview" : "Tap to preview",
            memoryText: "Adds to Recent",
            copyText: isRunningOnMac ? "Right-click to copy" : "Long-press to copy"
        )
    }

    var columns: [GridItem] {
        browseGridLayout.gridColumns
    }

    var fontSize: CGFloat {
        browseGridLayout.characterFontSize
    }

    var useTraditionalBrowseImageScript: Bool {
        browseImageScriptMode == "traditional"
    }

    var freePageLimit: Int { 100 }

    var hasUnlimitedFreePages: Bool {
        !entitlement.requiresPro(.datedCopies)
    }

    var freePagesRemaining: Int {
        max(0, freePageLimit - freePageUseCount)
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
                        focusBrowseGrid(on: newValue)
                        scrollToBrowseTile(activeBrowseTileAnchorID() ?? dictionaryTileAnchorID(newValue), proxy: proxy)
                    }
                } else {
                    scrollToPendingBrowseTarget(proxy: proxy)
                }
            }
            .onChange(of: store.activeSidebarPhrasePreview?.word) { _, newValue in
                if newValue == nil {
                    scrollToPendingBrowseTarget(proxy: proxy)
                }
            }
            .onChange(of: store.selectedBrowseCollectionID) { _, _ in
                lastTappedImageOffset = nil
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
            .sheet(item: $translationReportCollection) { collection in
                BrowseTranslationReportSheet(
                    collectionName: collection.name,
                    report: $translationReportDraft,
                    updatedAt: collection.translationReportUpdatedAt,
                    onPaste: pasteTranslationReport,
                    onSave: { saveTranslationReport(collection) },
                    onClear: { clearTranslationReport(collection) },
                    onDone: { translationReportCollection = nil }
                )
            }
            .sheet(item: $phraseExtractionCollection) { collection in
                BrowsePhraseExtractionSheet(
                    collectionName: collection.name,
                    prompt: store.promptText(for: .collection(collection), selectedTaskIDs: ["task4"]),
                    output: $phraseExtractionOutput,
                    message: imageActionMessage,
                    onCopyPrompt: { copyImageActionPrompt(collection: collection, taskID: "task4") },
                    onOpenAI: { openImageActionPrompt(collection: collection, taskID: "task4") },
                    onPaste: { phraseExtractionOutput = clipboardText() },
                    onAdd: { addManualExtractedPhrases(collection) },
                    onDone: { phraseExtractionCollection = nil }
                )
                .environmentObject(store)
            }
            .sheet(item: $pagePhraseListCollection) { collection in
                BrowsePagePhraseListSheet(collectionID: collection.id)
                    .environmentObject(store)
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
    func browseContent(proxy: ScrollViewProxy) -> some View {
        if isPhoneBrowseLayout {
            browseHintIfNeeded
                .padding(.top, 10)
        }

        if let collection = store.selectedBrowseCollection {
            imageGridContent(collection: collection, proxy: proxy)
        } else {
            smartGridContent(proxy: proxy)
        }
    }

    var browseWorkspaceHeader: some View { EmptyView() }
}
