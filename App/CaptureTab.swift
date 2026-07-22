import SwiftUI

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.openURL) private var openURL
    @Binding private var shouldOpenCamera: Bool
    @State private var showImageFileImporter = false
    @State private var selectedImage: CapturedImage?
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var gridPage = 0
    @State private var showCamera = false
    @State private var capturePreviewCharacter: String?
    @State private var captureDetailPreviewCharacter: String?
    @State private var lastSavedCollectionID: UUID?
    @State private var freePageUseCount = RadixCaptureUsage.freeScanCount

    private let freePageLimit = 100

    init(shouldOpenCamera: Binding<Bool> = .constant(false)) {
        _shouldOpenCamera = shouldOpenCamera
    }

    private enum CaptureSource {
        case camera
        case importTool
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
                Task { await recognize(image, source: .importTool) }
            },
            onError: { error in
                errorMessage = error.localizedDescription
            }
        ))
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                Task {
                    await recognize(image, source: .camera)
                }
            } onError: { error in
                showCamera = false
                errorMessage = error.localizedDescription
            }
            .presentationDetents([.large])
        }
        .onAppear {
            freePageUseCount = RadixCaptureUsage.freeScanCount
            openRequestedCameraIfNeeded()
            openStoreRequestedCameraIfNeeded()
        }
        .onChange(of: shouldOpenCamera) { _, _ in
            openRequestedCameraIfNeeded()
        }
        .onChange(of: store.shouldOpenCaptureCamera) { _, _ in
            openStoreRequestedCameraIfNeeded()
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
                Task { await recognize(image, source: .importTool) }
            },
            onAlbumError: { error in
                errorMessage = error.localizedDescription
            },
            onFiles: {
                guard !entitlement.requiresPro(.datedCopies) else {
                    store.showPaywall(for: .datedCopies)
                    return
                }
                showImageFileImporter = true
            }
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
            onDelete: deleteSavedImage
        )
    }

    private func openSavedImage(_ collection: CharacterCollection) {
        store.goToBrowse()
        store.selectBrowseCollection(id: collection.id)
    }

    private func deleteSavedImage(_ collection: CharacterCollection) {
        store.deleteCollection(id: collection.id)
        if lastSavedCollectionID == collection.id {
            lastSavedCollectionID = nil
        }
        statusMessage = "Deleted \(collection.name)."
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
    private func recognize(_ image: CapturedImage, source: CaptureSource) async {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        do {
            selectedImage = image
            let text = try await CaptureOCRService().recognizeText(in: image)
            let foundCharacters = CaptureTextExtractor.allCharactersInOrder(in: text)
            let foundPhrases = CaptureTextExtractor.uniquePhrases(in: text)
            store.activeCaptureDraft = CaptureDraft(
                rawText: text,
                charactersText: foundCharacters.joined(separator: " "),
                phrasesText: foundPhrases.joined(separator: "\n")
            )
            gridPage = 0
            clearCapturePreview()
            if foundCharacters.isEmpty {
                statusMessage = CaptureStatusText.noChineseCharactersFound
            } else {
                autoSaveAndBrowseRecognizedImage(image: image, source: source)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func autoSaveAndBrowseRecognizedImage(image: CapturedImage, source: CaptureSource) {
        guard let collection = store.createCollection(
            name: defaultOCRCollectionName,
            sourceText: store.activeCaptureDraft.charactersText,
            sourceType: .ocr,
            thumbnailJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image),
            sourceImageJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image, maxDimension: 1600),
            originalOCRText: store.activeCaptureDraft.rawText
        ) else {
            statusMessage = CaptureStatusText.noChineseCharactersFound
            return
        }

        if source == .camera && !hasUnlimitedFreePages {
            freePageUseCount = RadixCaptureUsage.incrementFreeScanCount(limit: freePageLimit)
        }

        lastSavedCollectionID = collection.id
        clearCaptureDraft()
        store.goToBrowse()
        store.selectBrowseCollection(id: collection.id)
        clearPhoneBrowsePreviewAfterImageSave()
    }

    private func clearPhoneBrowsePreviewAfterImageSave() {
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

    private func openRequestedCameraIfNeeded() {
        guard shouldOpenCamera else { return }
        shouldOpenCamera = false
        startCameraScan()
    }

    private func openStoreRequestedCameraIfNeeded() {
        guard store.shouldOpenCaptureCamera else { return }
        store.shouldOpenCaptureCamera = false
        startCameraScan()
    }

}
