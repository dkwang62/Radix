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
    @State private var phraseDiscoveryOutput = ""
    @State private var phraseDiscoveryCandidates: [PhraseDiscoveryCandidate] = []
    @State private var phraseDiscoveryStats = PhraseDiscoveryStats()
    @State private var phraseDiscoveryMessage: String?
    @State private var phraseDiscoveryAddedPhrases: [PhraseDiscoveryCandidate] = []
    @State private var phraseDiscoveryPromptCopied = false
    @State private var phraseDiscoveryImportedCount = 0
    @State private var phraseMode: CapturePhraseMode = .apple
    @State private var parserSource: PhraseParserSource = .appleCandidates
    @State private var parserInputPhrases: [String] = []
    @State private var lastSavedCollectionID: UUID?
    @State private var showPasteCollectionSheet = false
    @State private var pasteCollectionName = ""
    @State private var pasteCollectionText = ""

    private var characters: [String] {
        CaptureTextExtractor.uniqueCharacters(in: store.activeCaptureDraft.charactersText)
    }

    private var characterItems: [ComponentItem] {
        store.items(for: characters)
    }

    private var canBuildParserPrompt: Bool {
        switch parserSource {
        case .appleCandidates:
            return !parserInputPhrases.isEmpty
        case .chatGPTDerived:
            return !store.activeCaptureDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var captureWorkflowSteps: [CaptureWorkflowStep] {
        CaptureWorkflowStepBuilder.makeSteps(
            parserSource: parserSource,
            defaultAIName: store.defaultAIName,
            promptCopied: phraseDiscoveryPromptCopied,
            output: phraseDiscoveryOutput,
            importedCount: phraseDiscoveryImportedCount,
            candidateCount: phraseDiscoveryCandidates.count
        )
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
        .sheet(isPresented: $showPasteCollectionSheet) {
            pasteCollectionSheet
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

    private func beginPasteCollection() {
        pasteCollectionName = ""
        pasteCollectionText = UIPasteboard.general.string ?? ""
        showPasteCollectionSheet = true
    }

    private var pasteCollectionSheet: some View {
        PasteCollectionSheet(
            name: $pasteCollectionName,
            text: $pasteCollectionText,
            onCancel: { showPasteCollectionSheet = false },
            onSave: savePasteCollection
        )
    }

    private func savePasteCollection() {
        guard let collection = store.createCollection(
            name: CaptureCollectionName.pastedName(pasteCollectionName),
            sourceText: pasteCollectionText,
            sourceType: .manual
        ) else { return }
        store.selectBrowseCollection(id: collection.id)
        lastSavedCollectionID = collection.id
        statusMessage = CaptureStatusText.savedCollection(
            name: collection.name,
            characterCount: collection.characters.count
        )
        pasteCollectionName = ""
        pasteCollectionText = ""
        showPasteCollectionSheet = false
    }

    private var emptyState: some View {
        VStack(alignment: .leading, spacing: 16) {
            imageWorkbenchPanel {
                addChatGPTAnswerPanel
            }
        }
    }

    private func imageWorkbenchPanel<Footer: View>(@ViewBuilder footer: @escaping () -> Footer) -> some View {
        ImageWorkbenchPanel(
            isBrowseDisabled: store.allCollections.isEmpty,
            onCreateFromPaste: beginPasteCollection,
            onBrowseSavedImages: browseSavedImages,
            footer: footer
        )
    }

    private func browseSavedImages() {
        let targetID = CaptureBrowseTargetResolver.targetID(
            lastSavedCollectionID: lastSavedCollectionID,
            selectedBrowseCollectionID: store.selectedBrowseCollectionID,
            collections: store.allCollections
        )
        store.goToBrowse()
        if let targetID {
            store.selectBrowseCollection(id: targetID)
        }
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
            imageWorkbenchPanel {
                if phraseMode == .apple {
                    addChatGPTAnswerPanel
                } else {
                    Button {
                        phraseMode = .apple
                    } label: {
                        Label("Back to Apple-Derived Phrases", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                }
            }

            switch phraseMode {
            case .parser:
                phraseDiscoveryImportSection
            case .apple:
                EmptyView()
            }
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

    private var addChatGPTAnswerPanel: some View {
        AddExtractsToPhrasesPanel(
            defaultAIName: store.defaultAIName,
            output: $phraseDiscoveryOutput,
            message: phraseDiscoveryMessage,
            addedPhrases: phraseDiscoveryAddedPhrases,
            onAdd: addPhraseDiscoveryOutputToMyPhrases,
            onClear: clearPhraseDiscoveryInput,
            onDeleteAddedPhrase: deleteAddedPhrase
        )
    }

    private var phraseDiscoveryImportSection: some View {
        CaptureSection(parserSource.title) {
            PhraseDiscoveryImportContent(
                parserSource: parserSource,
                defaultAIName: store.defaultAIName,
                parserInputCount: parserInputPhrases.count,
                rawText: store.activeCaptureDraft.rawText,
                workflowSteps: captureWorkflowSteps,
                canBuildPrompt: canBuildParserPrompt,
                promptCopied: phraseDiscoveryPromptCopied,
                output: $phraseDiscoveryOutput,
                candidates: phraseDiscoveryCandidates,
                candidateBinding: candidateBinding(for:),
                addedPhrases: phraseDiscoveryAddedPhrases,
                summarySourceTitle: phraseDiscoverySummarySource.title,
                summarySourceCount: phraseDiscoverySummarySource.count,
                stats: phraseDiscoveryStats,
                message: phraseDiscoveryMessage,
                onOpenPrompt: copyPhraseDiscoveryPrompt,
                onPasteAndAdd: pasteAndAddPhraseDiscoveryOutput,
                onClear: { resetPhraseDiscovery(keepMode: true) },
                onAddFromBox: addPhraseDiscoveryOutputToMyPhrases,
                onPreviewAnswer: { readPhraseDiscoveryOutput(addImmediately: false) },
                onSelectAll: { setAllPhraseDiscoveryCandidates(true) },
                onDeselectAll: { setAllPhraseDiscoveryCandidates(false) },
                onImportSelected: importSelectedPhraseDiscoveryCandidates,
                onDeleteAddedPhrase: deleteAddedPhrase
            )
        }
    }

    private var phraseDiscoverySummarySource: (title: String, count: Int) {
        let knownCount = store.phraseDiscoveryKnownPhrases(in: store.activeCaptureDraft.rawText).count
        let sourceTitle = parserSource == .appleCandidates ? "Input" : "Known in OCR"
        let sourceCount = parserSource == .appleCandidates ? parserInputPhrases.count : knownCount
        return (sourceTitle, sourceCount)
    }

    private func candidateBinding(for candidate: PhraseDiscoveryCandidate) -> Binding<PhraseDiscoveryCandidate> {
        Binding(
            get: {
                phraseDiscoveryCandidates.first(where: { $0.id == candidate.id }) ?? candidate
            },
            set: { updatedCandidate in
                guard let index = phraseDiscoveryCandidates.firstIndex(where: { $0.id == updatedCandidate.id }) else { return }
                phraseDiscoveryCandidates[index] = updatedCandidate
            }
        )
    }

    private func copyPhraseDiscoveryPrompt() {
        let prompt = makePhraseDiscoveryPrompt()
        #if canImport(UIKit)
        UIPasteboard.general.string = prompt
        #endif
        phraseDiscoveryPromptCopied = true
        phraseDiscoveryMessage = CapturePhrasePromptLaunchMessage.opening(
            defaultAIName: store.defaultAIName,
            prefillsPrompt: store.defaultAIPrefillsPrompt
        )
        if let url = store.defaultAIURL(prompt: prompt) {
            DispatchQueue.main.asyncAfter(deadline: .now() + 3.0) {
                openURL(url)
            }
        }
    }

    private func makePhraseDiscoveryPrompt() -> String {
        let rawText = store.activeCaptureDraft.rawText
        return CapturePhrasePromptBuilder.makePrompt(
            source: parserSource,
            parserInputPhrases: parserInputPhrases,
            rawText: rawText,
            knownPhrases: store.phraseDiscoveryKnownPhrases(in: rawText)
        )
    }

    private func readPhraseDiscoveryOutput(addImmediately: Bool) {
        phraseDiscoveryImportedCount = 0
        let parsed = PhraseDiscoveryParser.parse(phraseDiscoveryOutput)
        let parsedPhrases = Set(parsed.candidates.map(\.phrase))
        let readResult = PhraseDiscoveryReader.read(
            parsed,
            existingWords: store.existingPhraseWords(in: parsedPhrases)
        )
        phraseDiscoveryCandidates = readResult.candidates
        phraseDiscoveryStats = readResult.stats
        if addImmediately {
            addPhraseDiscoveryCandidates(phraseDiscoveryCandidates)
        } else {
            phraseDiscoveryMessage = PhraseDiscoveryPreviewMessage.message(
                candidateCount: phraseDiscoveryCandidates.count
            )
        }
    }

    private func addPhraseDiscoveryOutputToMyPhrases() {
        readPhraseDiscoveryOutput(addImmediately: true)
    }

    private func pasteAndAddPhraseDiscoveryOutput() {
        #if canImport(UIKit)
        let clipboardText = UIPasteboard.general.string ?? ""
        #else
        let clipboardText = ""
        #endif

        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phraseDiscoveryMessage = CaptureStatusText.clipboardIsEmpty
            return
        }

        phraseDiscoveryOutput = clipboardText
        readPhraseDiscoveryOutput(addImmediately: true)
    }

    private func clearPhraseDiscoveryInput() {
        phraseDiscoveryOutput = ""
        phraseDiscoveryCandidates = []
        phraseDiscoveryAddedPhrases = []
        phraseDiscoveryStats = PhraseDiscoveryStats()
        phraseDiscoveryMessage = nil
        phraseDiscoveryImportedCount = 0
    }

    private func clearCaptureResults() {
        clearCaptureDraft()
        statusMessage = nil
        errorMessage = nil
        resetPhraseDiscovery()
    }

    private func setAllPhraseDiscoveryCandidates(_ isSelected: Bool) {
        phraseDiscoveryCandidates = PhraseDiscoveryCandidateTools.selectingAll(
            phraseDiscoveryCandidates,
            isSelected: isSelected
        )
    }

    private func importSelectedPhraseDiscoveryCandidates() {
        let selected = phraseDiscoveryCandidates.filter(\.isSelected)
        addPhraseDiscoveryCandidates(selected)
    }

    private func addPhraseDiscoveryCandidates(_ selected: [PhraseDiscoveryCandidate]) {
        var added = 0
        var addedCandidates: [PhraseDiscoveryCandidate] = []
        var errors: [String] = []
        let prepared = PhraseDiscoveryCandidateTools.preparingForImport(selected)

        for item in prepared.candidates {
            do {
                try store.addCustomPhrase(
                    word: item.phrase,
                    pinyin: item.candidate.pinyin,
                    meanings: item.candidate.meaning,
                    notes: nil,
                    refreshViews: false
                )
                added += 1
                addedCandidates.append(item.candidate)
            } catch {
                errors.append("\(item.phrase): \(error.localizedDescription)")
            }
        }

        store.refreshPhraseOverlayViews()
        phraseDiscoveryImportedCount = added
        phraseDiscoveryAddedPhrases = PhraseDiscoveryCandidateTools.mergingAddedResults(
            phraseDiscoveryAddedPhrases,
            addedCandidates
        )
        let selectedIDs = Set(selected.map(\.id))
        phraseDiscoveryCandidates = PhraseDiscoveryCandidateTools.deselecting(
            phraseDiscoveryCandidates,
            ids: selectedIDs
        )
        let summary = PhraseDiscoveryImportSummary(
            selectedCount: selected.count,
            addedCount: added,
            skippedCount: prepared.skippedCount,
            errors: errors
        )
        phraseDiscoveryMessage = summary.message(defaultAIName: store.defaultAIName)
    }

    private func deleteAddedPhrase(_ candidate: PhraseDiscoveryCandidate) {
        store.removeDataEditPhrase(word: candidate.phrase)
        phraseDiscoveryAddedPhrases.removeAll { $0.phrase == candidate.phrase }
        phraseDiscoveryImportedCount = phraseDiscoveryAddedPhrases.count
        phraseDiscoveryMessage = CaptureStatusText.removedPhrase(candidate.phrase)
    }

    private func resetPhraseDiscovery(keepMode: Bool = false) {
        phraseDiscoveryOutput = ""
        phraseDiscoveryCandidates = []
        phraseDiscoveryAddedPhrases = []
        phraseDiscoveryStats = PhraseDiscoveryStats()
        phraseDiscoveryMessage = nil
        phraseDiscoveryPromptCopied = false
        phraseDiscoveryImportedCount = 0
        if !keepMode {
            parserInputPhrases = []
            parserSource = .appleCandidates
            phraseMode = .apple
        }
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
            resetPhraseDiscovery()
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
        resetPhraseDiscovery()
        store.goToBrowse()
        store.selectBrowseCollection(id: collection.id)
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
