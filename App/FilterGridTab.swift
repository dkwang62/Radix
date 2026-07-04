import SwiftUI

enum BrowseAIFallbackTask: Identifiable {
    case checkOCR(CharacterCollection)
    case extractPhrases(CharacterCollection)
    case translate(CharacterCollection)
    case extractSentences(CharacterCollection)
    case createPagePractice(CharacterCollection)

    var id: String {
        switch self {
        case .checkOCR(let collection): return "ocr-\(collection.id)"
        case .extractPhrases(let collection): return "extract-\(collection.id)"
        case .translate(let collection): return "translate-\(collection.id)"
        case .extractSentences(let collection): return "sentences-\(collection.id)"
        case .createPagePractice(let collection): return "page-practice-\(collection.id)"
        }
    }
}

struct FilterGridTab: View {
    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    @State var hasShownBrowseInteractionHintRow = RadixBrowsePreferences.hasShownInteractionHint
    @State var browseImageScriptMode = RadixBrowsePreferences.imageScriptMode
    @State var browsePageSortOrder = RadixBrowsePreferences.pageSortOrder
    @State var freePageUseCount = RadixCaptureUsage.freeScanCount
    @State var showBrowseFilters = false
    @State var showManualCollectionSheet = false
    @State var showBrowseCamera = false
    @State var showBrowseImageFileImporter = false
    @State var showBrowseSource = false
    @State var showDictionaryHelp = false
    @State var showBrowseInteractionHint = false
    @State var manualCollectionName = ""
    @State var manualCollectionText = ""
    @State var editingCollection: CharacterCollection?
    @State var editingCollectionName = ""
    @State var editingCollectionText = ""
    @State var collectionEditorError: String?
    @State var translationReportCollection: CharacterCollection?
    @State var translationReportDraft = ""
    @State var pageQuizCollection: CharacterCollection?
    @State var pageQuizQuestions: [PageQuizQuestion] = []
    @State var pageQuizMessage: String?
    @State var isGeneratingPageQuiz = false
    @State var pagePhraseListCollection: CharacterCollection?
    @State var imageActionMessage: String?
    @State var aiFallbackTask: BrowseAIFallbackTask?
    @State var automaticAIError = ""
    @State var isRunningImageAction = false
    @State var isProcessingBrowseImageImport = false
    @State var lastTappedImageOffset: Int?

    var isRunningOnMac: Bool {
        RadixPlatform.isRunningOnMac
    }

    var isPhoneBrowseLayout: Bool {
        RadixPlatform.isPhone
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
                            if RadixPlatform.isPhone {
                                phoneBrowsePreview(proxy: proxy)
                            }
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
                                if !showBrowseSource {
                                    browseContent(proxy: proxy)
                                }
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
            .onChange(of: browseImageScriptMode) { _, newValue in
                RadixBrowsePreferences.imageScriptMode = newValue
            }
            .onAppear {
                hasShownBrowseInteractionHintRow = RadixBrowsePreferences.hasShownInteractionHint
                browseImageScriptMode = RadixBrowsePreferences.imageScriptMode
                browsePageSortOrder = RadixBrowsePreferences.pageSortOrder
                freePageUseCount = RadixCaptureUsage.freeScanCount
                prepareBrowseHintIfNeeded()
                consumeBrowsePageRequests()
                scrollToPendingBrowseTarget(proxy: proxy)
            }
            .onChange(of: store.shouldOpenBrowsePages) { _, _ in
                consumeBrowsePageRequests()
            }
            .onChange(of: store.shouldCloseBrowsePages) { _, _ in
                consumeBrowsePageRequests()
            }
            .onChange(of: store.shouldStartBrowseCamera) { _, _ in
                consumeBrowsePageRequests()
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
            .sheet(item: $pageQuizCollection) { collection in
                BrowsePageQuizSheet(
                    collectionName: collection.name,
                    questions: pageQuizQuestions,
                    message: pageQuizMessage,
                    isGenerating: isGeneratingPageQuiz,
                    canSetUpGeminiKey: store.geminiAPIKey
                        .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                    onUseLocalFallback: { useLocalPageQuizFallback(collection) },
                    onSetUpGeminiKey: {
                        pageQuizCollection = nil
                        DispatchQueue.main.async {
                            store.goToSettingsForAPIKeySetup()
                        }
                    },
                    onDone: { pageQuizCollection = nil }
                )
            }
            .sheet(item: $pagePhraseListCollection) { collection in
                BrowsePagePhraseListSheet(collectionID: collection.id)
                    .environmentObject(store)
            }
            .sheet(isPresented: $showBrowseCamera) {
                CameraCaptureView { image in
                    showBrowseCamera = false
                    Task { await recognizeBrowseImage(image) }
                } onError: { error in
                    showBrowseCamera = false
                    imageActionMessage = error.localizedDescription
                }
            }
            .alert(item: $aiFallbackTask) { task in
                Alert(
                    title: Text("Automatic AI Is Unavailable"),
                    message: Text("\(automaticAIError)\n\nYour API key may still be valid. Gemini can occasionally be unavailable, so the copy-and-paste method remains available."),
                    primaryButton: .default(Text("Use Another AI App")) {
                        useManualFallback(task)
                    },
                    secondaryButton: .cancel(Text("Not Now"))
                )
            }
            .modifier(CaptureFileImportModifier(
                isPresented: $showBrowseImageFileImporter,
                onImage: { image in
                    Task { await recognizeBrowseImage(image) }
                },
                onError: { error in
                    imageActionMessage = error.localizedDescription
                }
            ))
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
