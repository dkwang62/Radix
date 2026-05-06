import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.openURL) private var openURL
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showImageFileImporter = false
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var gridPage = 0
    @State private var showCamera = false
    @State private var capturePreviewCharacter: String?
    @State private var captureDetailPreviewCharacter: String?
    @State private var lastSavedCollectionID: UUID?

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
                    header

                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone,
                       let current = captureDetailPreviewCharacter ?? capturePreviewCharacter ?? store.previewCharacter,
                       store.item(for: current) != nil {
                        standardPhoneCharacterPreview(
                            character: current,
                            onClear: {
                                capturePreviewCharacter = nil
                                captureDetailPreviewCharacter = nil
                                store.previewCharacter = nil
                            }
                        )
                    }
                    #endif

                    CaptureStatusMessages(errorMessage: errorMessage, statusMessage: statusMessage)

                    CaptureImagePreview(image: selectedImage)

                    if isProcessing {
                        ProgressView("Reading image...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if store.activeCaptureDraft.rawText.isEmpty {
                        emptyState
                    } else {
                        captureResults(scrollToTop: {
                            withAnimation { proxy.scrollTo("captureTop", anchor: .top) }
                        })
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .onAppear {
            #if !targetEnvironment(macCatalyst)
            let isOnMac = ProcessInfo.processInfo.isiOSAppOnMac
            if !isOnMac, UIImagePickerController.isSourceTypeAvailable(.camera) {
                showCamera = true
            }
            #endif
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadAndRecognize(item) }
        }
        .fileImporter(
            isPresented: $showImageFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            Task { await loadAndRecognizeFile(result) }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                Task { await recognize(image) }
            }
        }
    }

    private var header: some View {
        CaptureHeaderView(
            selectedPhoto: $selectedPhoto,
            isProcessing: isProcessing,
            filePickerTitle: filePickerTitle,
            onCamera: { showCamera = true },
            onFiles: { showImageFileImporter = true }
        )
    }

    private var filePickerTitle: String {
        #if targetEnvironment(macCatalyst)
        return "Finder"
        #else
        return "Files"
        #endif
    }

    private var defaultOCRCollectionName: String {
        CaptureCollectionName.ocrImageName()
    }

    private var emptyState: some View {
        savedImagesList
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
            charactersText: $store.activeCaptureDraft.charactersText,
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
    private func loadAndRecognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            await recognize(try await CaptureImageLoader.image(from: item))
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func loadAndRecognizeFile(_ result: Result<[URL], Error>) async {
        do {
            guard let image = try CaptureImageLoader.image(from: result.get()) else { return }
            await recognize(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func recognize(_ image: UIImage) async {
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
                autoSaveAndBrowseRecognizedImage(image: image)
            }
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    private func autoSaveAndBrowseRecognizedImage(image: UIImage) {
        guard let collection = store.createCollection(
            name: defaultOCRCollectionName,
            sourceText: store.activeCaptureDraft.charactersText,
            sourceType: .ocr,
            thumbnailJPEGData: CaptureImageThumbnailer.makeJPEGData(from: image)
        ) else {
            statusMessage = CaptureStatusText.noChineseCharactersFound
            return
        }

        lastSavedCollectionID = collection.id
        clearCaptureDraft()
        store.goToBrowse()
        store.selectBrowseCollection(id: collection.id)
        clearPhoneBrowsePreviewAfterImageSave()
    }

    private func clearPhoneBrowsePreviewAfterImageSave() {
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone {
            store.clearBrowsePreview()
            store.showiPhoneDetail = false
        }
        #endif
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

}
