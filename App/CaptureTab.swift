import SwiftUI
#if canImport(PhotosUI)
import PhotosUI
#endif

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.openURL) private var openURL
    @State private var showImageFileImporter = false
    @State private var selectedImage: CapturedImage?
    @State private var isProcessing = false
    @State private var recognitionTask: Task<Void, Never>?
    @State private var activeRecognitionID: UUID?
    @State private var captureContextAllowsAutoOpen = false
    @State private var pendingCloudOCR: PendingCloudOCR?
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var gridPage = 0
    @State private var showCamera = false
    @State private var showManualCollectionSheet = false
    @State private var manualCollectionName = ""
    @State private var manualCollectionText = ""
    #if canImport(PhotosUI)
    @State private var showAlbumImporter = false
    @State private var selectedAlbumPhoto: PhotosPickerItem?
    #endif
    @State private var capturePreviewCharacter: String?
    @State private var captureDetailPreviewCharacter: String?
    @State private var lastSavedCollectionID: UUID?
    @State private var pendingDeleteCollection: CharacterCollection?
    @State private var freePageUseCount = RadixCaptureUsage.freeScanCount

    private let freePageLimit = 100

    private enum CaptureSource {
        case camera
        case importTool
    }

    private struct PendingCloudOCR: Identifiable {
        let id = UUID()
        let image: CapturedImage
        let source: CaptureSource
        let localResult: CaptureLocalOCRResult
    }

    private var characters: [String] {
        CaptureTextExtractor.uniqueCharacters(in: store.activeCaptureDraft.charactersText)
    }

    private var characterItems: [ComponentItem] {
        store.items(for: characters)
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 0).id("captureTop")
                    if isPhoneCapturePreviewActive {
                        phoneCapturePreview
                    } else if store.activeCaptureDraft.rawText.isEmpty {
                        header
                        CaptureStatusMessages(errorMessage: errorMessage, statusMessage: statusMessage)
                        CaptureImagePreview(image: selectedImage)
                        if isProcessing {
                            ProgressView("Reading image...")
                                .frame(maxWidth: .infinity, alignment: .center)
                                .padding(.vertical, 24)
                        } else {
                            emptyState
                        }
                    } else {
                        header
                        CaptureStatusMessages(errorMessage: errorMessage, statusMessage: statusMessage)
                        CaptureImagePreview(image: selectedImage)
                        captureResults(scrollToTop: {
                            withAnimation { proxy.scrollTo("captureTop", anchor: .top) }
                        })
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
            .onChange(of: store.activeSidebarPhrasePreview?.word) { _, newValue in
                guard newValue != nil else { return }
                capturePreviewCharacter = nil
                captureDetailPreviewCharacter = nil
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("captureTop", anchor: .top)
                }
            }
        }
        .modifier(CaptureFileImportModifier(
            isPresented: $showImageFileImporter,
            onImage: { image in
                beginRecognition(image, source: .importTool)
            },
            onError: { error in
                errorMessage = error.localizedDescription
            }
        ))
        #if canImport(PhotosUI)
        .photosPicker(isPresented: $showAlbumImporter, selection: $selectedAlbumPhoto, matching: .images)
        .onChange(of: selectedAlbumPhoto) { _, item in
            guard let item else { return }
            Task {
                do {
                    let image = try await CaptureImageLoader.capturedImage(from: item)
                    await MainActor.run {
                        selectedAlbumPhoto = nil
                        beginRecognition(image, source: .importTool)
                    }
                } catch {
                    await MainActor.run {
                        selectedAlbumPhoto = nil
                        errorMessage = error.localizedDescription
                    }
                }
            }
        }
        #endif
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                beginRecognition(image, source: .camera)
            } onError: { error in
                showCamera = false
                errorMessage = error.localizedDescription
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $showManualCollectionSheet) {
            ManualBrowseCollectionSheet(
                name: $manualCollectionName,
                text: $manualCollectionText,
                onCancel: { showManualCollectionSheet = false },
                onSave: saveManualCollection
            )
            .presentationDetents([.medium, .large])
        }
        .alert("Delete Saved Page?", isPresented: Binding(
            get: { pendingDeleteCollection != nil },
            set: { if !$0 { pendingDeleteCollection = nil } }
        )) {
            Button("Delete", role: .destructive) {
                confirmDeleteSavedImage()
            }
            Button("Cancel", role: .cancel) {
                pendingDeleteCollection = nil
            }
        } message: {
            if let collection = pendingDeleteCollection {
                Text(store.deletionImpact(for: collection).alertMessage)
            }
        }
        .alert(item: $pendingCloudOCR) { request in
            Alert(
                title: Text("Try Cloud OCR?"),
                message: Text("\(request.localResult.userMessage)\n\nTrying Gemini sends this image to Google's Gemini service. It requires a Gemini key in Settings."),
                primaryButton: .default(Text("Try Gemini")) {
                    beginRecognition(request.image, source: request.source, method: .gemini)
                },
                secondaryButton: .cancel(Text("Not Now"))
            )
        }
        .onAppear {
            freePageUseCount = RadixCaptureUsage.freeScanCount
            openRequestedCaptureSourceIfNeeded()
        }
        .onChange(of: store.shouldOpenCaptureCamera) { _, _ in
            openRequestedCaptureSourceIfNeeded()
        }
        .onChange(of: store.shouldOpenCaptureTextPage) { _, _ in
            openRequestedCaptureSourceIfNeeded()
        }
        .onChange(of: store.shouldOpenCaptureClipboardImage) { _, _ in
            openRequestedCaptureSourceIfNeeded()
        }
        .onChange(of: store.shouldOpenCaptureAlbum) { _, _ in
            openRequestedCaptureSourceIfNeeded()
        }
        .onChange(of: store.shouldOpenCaptureFiles) { _, _ in
            openRequestedCaptureSourceIfNeeded()
        }
        .onChange(of: store.route) { _, route in
            if route != .capture {
                captureContextAllowsAutoOpen = false
            }
        }
        .onDisappear {
            captureContextAllowsAutoOpen = false
        }
    }

    private var header: some View {
        CaptureHeaderView(
            isProcessing: isProcessing,
            filePickerTitle: filePickerTitle,
            isImportLocked: entitlement.requiresPro(.datedCopies),
            freeScanStatusText: freeScanStatusText,
            onCamera: startCameraScan,
            onLockedImport: { store.showPaywall(for: .datedCopies) },
            onAlbumImage: { image in
                beginRecognition(image, source: .importTool)
            },
            onAlbumError: { error in
                errorMessage = error.localizedDescription
            },
            onFiles: {
                beginFileImport()
            },
            onClipboard: beginClipboardImageImport,
            onText: beginManualCollection
        )
    }

    private var hasUnlimitedFreePages: Bool {
        !entitlement.requiresPro(.datedCopies)
    }

    private var freePagesRemaining: Int {
        max(0, freePageLimit - freePageUseCount)
    }

    private var freeScanStatusText: String {
        hasUnlimitedFreePages ? "Unlimited pages" : "\(freePagesRemaining) free pages left"
    }

    private var filePickerTitle: String {
        #if targetEnvironment(macCatalyst)
        return "Finder"
        #else
        return "Files"
        #endif
    }

    private var defaultOCRCollectionName: String {
        ""
    }

    private var emptyState: some View {
        savedImagesList
    }

    private var isPhoneCapturePreviewActive: Bool {
        guard RadixPlatform.isPhone else { return false }
        if store.activeSidebarPhrasePreview != nil { return true }
        let current = captureDetailPreviewCharacter ?? capturePreviewCharacter ?? store.previewCharacter
        return current.flatMap { store.item(for: $0) } != nil
    }

    private var phoneCapturePreview: some View {
        PhoneContextPreview(
            phrase: store.activeSidebarPhrasePreview,
            character: captureDetailPreviewCharacter ?? capturePreviewCharacter ?? store.previewCharacter,
            onReturn: {
                capturePreviewCharacter = nil
                captureDetailPreviewCharacter = nil
                store.previewCharacter = nil
                store.dismissSidebarPhrasePreview()
            }
        )
        .environmentObject(store)
    }

    private var savedImagesList: some View {
        SavedImageList(
            collections: store.allCollections,
            onOpen: openSavedImage,
            onDelete: requestDeleteSavedImage
        )
    }

    private func openSavedImage(_ collection: CharacterCollection) {
        store.goToPagesWorkspace(id: collection.id, preservingOrigin: true)
    }

    private func requestDeleteSavedImage(_ collection: CharacterCollection) {
        pendingDeleteCollection = collection
    }

    private func confirmDeleteSavedImage() {
        guard let collection = pendingDeleteCollection else { return }
        do {
            try store.deleteCollection(id: collection.id)
        } catch {
            errorMessage = "Delete failed: \(error.localizedDescription)"
            pendingDeleteCollection = nil
            return
        }
        if lastSavedCollectionID == collection.id {
            lastSavedCollectionID = nil
        }
        statusMessage = "Deleted \(collection.name)."
        pendingDeleteCollection = nil
    }

    private func readCaptureCharactersAloud() {
        let count = store.speakCharacters(in: store.activeCaptureDraft.charactersText)
        statusMessage = count > 0
            ? CaptureStatusText.readingCharacters(count: count)
            : CaptureStatusText.noChineseCharactersToRead
    }

    private func previewCaptureCharacter(_ character: String) {
        capturePreviewCharacter = character
        captureDetailPreviewCharacter = character
        store.refreshPhrases(for: character)
    }

    private func captureResults(scrollToTop: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            captureCharactersSection(scrollToTop: scrollToTop)
            savedImagesList
        }
    }

    private func captureCharactersSection(scrollToTop: @escaping () -> Void) -> some View {
        CaptureCharactersSection(
            characters: characters,
            characterItems: characterItems,
            currentPage: $gridPage,
            charactersText: store.presentationBinding(\.activeCaptureDraft.charactersText),
            onReadAloud: readCaptureCharactersAloud,
            onClear: clearCaptureResults,
            onPreview: previewCaptureCharacter,
            onSelect: scrollToTop
        )
    }

    private func clearCaptureResults() {
        clearCaptureDraft()
        statusMessage = nil
        errorMessage = nil
    }

    @MainActor
    private func beginRecognition(
        _ image: CapturedImage,
        source: CaptureSource,
        method: CaptureImageRecognitionMethod = .appleVision
    ) {
        recognitionTask?.cancel()
        pendingCloudOCR = nil
        let operationID = UUID()
        activeRecognitionID = operationID
        captureContextAllowsAutoOpen = store.route == .capture
        recognitionTask = Task { @MainActor in
            await recognize(image, source: source, method: method, operationID: operationID)
        }
    }

    @MainActor
    private func recognize(
        _ image: CapturedImage,
        source: CaptureSource,
        method: CaptureImageRecognitionMethod,
        operationID: UUID
    ) async {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        selectedImage = image
        defer {
            if activeRecognitionID == operationID {
                isProcessing = false
                activeRecognitionID = nil
                recognitionTask = nil
            }
        }

        do {
            let result: CaptureImageRecognitionResult
            switch method {
            case .appleVision:
                let localResult = try await store.recognizeImageTextLocally(in: image)
                guard activeRecognitionID == operationID, !Task.isCancelled else { return }
                switch localResult {
                case .recognized(let text):
                    result = CaptureImageRecognitionResult(text: text, method: .appleVision)
                case .noText, .nonChineseText, .failed:
                    statusMessage = localResult.userMessage
                    if store.route == .capture {
                        pendingCloudOCR = PendingCloudOCR(
                            image: image,
                            source: source,
                            localResult: localResult
                        )
                    }
                    return
                }
            case .gemini:
                result = try await store.recognizeImageTextWithGemini(in: image)
            }
            guard activeRecognitionID == operationID, !Task.isCancelled else { return }
            let foundCharacters = CaptureTextExtractor.allCharactersInOrder(in: result.text)
            let foundPhrases = CaptureTextExtractor.uniquePhrases(in: result.text)
            let recognizedDraft = CaptureDraft(
                rawText: result.text,
                charactersText: foundCharacters.joined(separator: " "),
                phrasesText: foundPhrases.joined(separator: "\n")
            )
            if captureContextAllowsAutoOpen && store.route == .capture {
                store.activeCaptureDraft = recognizedDraft
            }
            gridPage = 0
            clearCapturePreview()
            if foundCharacters.isEmpty {
                statusMessage = CaptureStatusText.noChineseCharactersFound
            } else {
                if result.usedAIFallback {
                    statusMessage = "Gemini read this image after you requested cloud OCR."
                }
                let shouldAutoOpen = CaptureCompletionNavigationPolicy.shouldAutoOpen(
                    operationID: operationID,
                    activeOperationID: activeRecognitionID,
                    captureContextIsActive: captureContextAllowsAutoOpen,
                    currentRoute: store.route
                )
                autoSaveRecognizedImage(
                    image: image,
                    source: source,
                    draft: recognizedDraft,
                    shouldAutoOpen: shouldAutoOpen
                )
            }
        } catch {
            guard activeRecognitionID == operationID, !Task.isCancelled else { return }
            errorMessage = error.localizedDescription
        }
    }

    private func autoSaveRecognizedImage(
        image: CapturedImage,
        source: CaptureSource,
        draft: CaptureDraft,
        shouldAutoOpen: Bool
    ) {
        guard let collection = store.createCollection(
            name: defaultOCRCollectionName,
            sourceText: draft.charactersText,
            sourceType: .ocr,
            sourceImageJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 1600),
            originalOCRText: draft.rawText
        ) else {
            statusMessage = CaptureStatusText.noChineseCharactersFound
            return
        }

        if source == .camera && !hasUnlimitedFreePages {
            freePageUseCount = RadixCaptureUsage.incrementFreeScanCount(limit: freePageLimit)
        }

        lastSavedCollectionID = collection.id
        clearCaptureDraft()
        if shouldAutoOpen {
            store.goToBrowseCollection(id: collection.id, preservingOrigin: true)
            clearPhonePreviewAfterPageSave()
        } else {
            statusMessage = "Page saved. Open it from Pages below."
        }
    }

    private func clearPhonePreviewAfterPageSave() {
        if RadixPlatform.isPhone {
            store.clearBrowsePreview()
            store.showiPhoneDetail = false
        }
    }

    private func clearCaptureDraft() {
        selectedImage = nil
        store.activeCaptureDraft = CaptureDraft()
        gridPage = 0
        clearCapturePreview()
    }

    private func clearCapturePreview() {
        capturePreviewCharacter = nil
        captureDetailPreviewCharacter = nil
    }

    private func startCameraScan() {
        guard hasUnlimitedFreePages || freePagesRemaining > 0 else {
            store.showPaywall(for: .datedCopies)
            return
        }
        showCamera = true
    }

    private func beginManualCollection() {
        guard hasUnlimitedFreePages || freePagesRemaining > 0 else {
            store.showPaywall(for: .datedCopies)
            return
        }
        manualCollectionName = ""
        manualCollectionText = ""
        showManualCollectionSheet = true
    }

    private func saveManualCollection() {
        guard let collection = store.createCollection(
            name: manualCollectionName,
            sourceText: manualCollectionText,
            sourceType: .manual
        ) else { return }

        if !hasUnlimitedFreePages {
            freePageUseCount = RadixCaptureUsage.incrementFreeScanCount(limit: freePageLimit)
        }

        lastSavedCollectionID = collection.id
        manualCollectionName = ""
        manualCollectionText = ""
        showManualCollectionSheet = false
        clearCaptureDraft()
        store.goToBrowseCollection(id: collection.id, preservingOrigin: true)
        clearPhonePreviewAfterPageSave()
    }

    private func openRequestedCaptureSourceIfNeeded() {
        if store.shouldOpenCaptureCamera {
            store.shouldOpenCaptureCamera = false
            startCameraScan()
        }

        if store.shouldOpenCaptureTextPage {
            store.shouldOpenCaptureTextPage = false
            beginManualCollection()
        }

        if store.shouldOpenCaptureClipboardImage {
            store.shouldOpenCaptureClipboardImage = false
            beginClipboardImageImport()
        }

        if store.shouldOpenCaptureAlbum {
            store.shouldOpenCaptureAlbum = false
            beginAlbumImport()
        }

        if store.shouldOpenCaptureFiles {
            store.shouldOpenCaptureFiles = false
            beginFileImport()
        }
    }

    private func beginClipboardImageImport() {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }

        do {
            guard let image = try RadixPlatform.pasteboardImage() else {
                errorMessage = "Copy an image with Chinese text first, then choose Image from Clipboard."
                return
            }
            beginRecognition(image, source: .importTool)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func beginAlbumImport() {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }
        #if canImport(PhotosUI)
        showAlbumImporter = true
        #else
        errorMessage = CocoaError(.featureUnsupported).localizedDescription
        #endif
    }

    private func beginFileImport() {
        guard !entitlement.requiresPro(.datedCopies) else {
            store.showPaywall(for: .datedCopies)
            return
        }
        showImageFileImporter = true
    }

}
