import Foundation
import Testing

@Suite("SwiftUI crash guardrails")
struct SwiftUICrashGuardrailTests {
    @Test("Smart Search examples remain fixed explicit children")
    func smartSearchExamplesAvoidDynamicForEach() throws {
        let source = try sourceText(at: "App/SmartSearchExamples.swift")

        #expect(!source.contains("ForEach("))
        #expect(source.components(separatedBy: "searchExampleButton(label:").count - 1 == 7)
    }

    @Test("Phrase animation chips avoid nested scroll readers")
    func phraseAnimationAvoidsScrollViewReader() throws {
        let source = try sourceText(at: "Views/PhraseInfoAnimation.swift")

        #expect(!source.contains("ScrollViewReader"))
        #expect(source.contains("ScrollView(.horizontal, showsIndicators: false)"))
    }

    @Test("Scene changes do not invalidate the full root navigation tree")
    func rootSceneLifecycleUsesIsolatedObserver() throws {
        let source = try sourceText(at: "App/RootView.swift")
        let rootViewSource = source.components(separatedBy: "private struct RadixSceneLifecycleObserver").first ?? source

        #expect(!rootViewSource.contains("@Environment(\\.scenePhase)"))
        #expect(rootViewSource.contains("RadixSceneLifecycleObserver("))
        #expect(source.contains("private struct RadixSceneLifecycleObserver"))
        #expect(source.components(separatedBy: "@Environment(\\.scenePhase)").count - 1 == 1)
    }

    @Test("Study root delegates section state and navigation transitions")
    func studyRootUsesSectionStateCoordinator() throws {
        let rootSource = try sourceText(at: "App/FavouritesTab.swift")
        let stateSource = try sourceText(at: "App/FavouritesStudyScreenState.swift")
        let lifecycleSource = try sourceText(at: "App/FavouritesTabLifecycle.swift")

        #expect(rootSource.components(separatedBy: "@State var").count - 1 == 1)
        #expect(rootSource.contains("@State var screenState = StudyScreenState()"))
        #expect(stateSource.contains("struct StudyNavigationScreenState"))
        #expect(stateSource.contains("struct StudySentenceScreenState"))
        #expect(stateSource.contains("struct StudyConversationPracticeScreenState"))
        #expect(stateSource.contains("struct StudyPageScreenState"))
        #expect(stateSource.contains("mutating func presentReview("))
        #expect(stateSource.contains("mutating func returnToOriginatingPage()"))
        #expect(lifecycleSource.contains("screenState.presentReview(scope: .all)"))
        #expect(lifecycleSource.contains("screenState.presentCheckpoints()"))
    }

    @Test("Capture confirms saved page deletion with the shared impact message")
    func captureSavedPageDeletionRequiresConfirmation() throws {
        let source = try sourceText(at: "App/CaptureTab.swift")

        #expect(source.contains("@State private var pendingDeleteCollection: CharacterCollection?"))
        #expect(source.contains("onDelete: requestDeleteSavedImage"))
        #expect(source.contains(".alert(\"Delete Saved Page?\""))
        #expect(source.contains("Text(store.deletionImpact(for: collection).alertMessage)"))
        #expect(source.contains("Button(\"Cancel\", role: .cancel)"))
        #expect(source.contains("private func confirmDeleteSavedImage()"))
        #expect(source.components(separatedBy: "store.deleteCollection(id: collection.id)").count - 1 == 1)
    }

    @Test("Phrase note editing returns to the latest committed value")
    func phraseNoteEditingUsesLatestCommittedValue() throws {
        let cardSource = try sourceText(at: "Views/PhraseInfoCard.swift")
        let headerSource = try sourceText(at: "Views/PhraseInfoHeader.swift")
        let notesSource = try sourceText(at: "Views/PhraseInfoNotes.swift")

        #expect(cardSource.contains("@State var committedNotes = \"\""))
        #expect(cardSource.components(separatedBy: "committedNotes = phrase.notes").count - 1 == 2)
        #expect(headerSource.contains("editableNotes = committedNotes"))
        #expect(!headerSource.contains("editableNotes = phrase.notes"))
        #expect(notesSource.contains("committedNotes = editableNotes"))
        #expect(notesSource.contains("editableNotes = committedNotes"))
        #expect(!notesSource.contains("editableNotes = phrase.notes"))
    }

    @Test("Quick editor destructive actions require confirmation")
    func quickEditorManagementActionsRequireConfirmation() throws {
        let sharedSource = try sourceText(at: "App/QuickEditSheets.swift")
        let characterViewSource = try sourceText(at: "App/QuickCharacterEditorView.swift")
        let characterActionSource = try sourceText(at: "App/QuickCharacterEditorActions.swift")
        let phraseSource = try sourceText(at: "App/QuickPhraseEditorView.swift")

        #expect(sharedSource.contains("enum QuickEditorManagementAction"))
        #expect(characterViewSource.contains(".alert("))
        #expect(characterActionSource.contains("pendingManagementAction = .delete"))
        #expect(characterActionSource.contains("pendingManagementAction = .revert"))
        #expect(characterActionSource.contains("Button(\"Revert\", role: .destructive)"))
        #expect(phraseSource.contains("isPresented: managementConfirmationBinding"))
        #expect(phraseSource.contains("Button(isBuiltIn ? \"Revert\" : \"Delete\", role: .destructive)"))
        #expect(phraseSource.contains("pendingManagementAction = isBuiltIn ? .revert : .delete"))
    }

    @Test("Single phrase deletion publishes UI changes only after persistence")
    func singlePhraseDeletionIsPersistenceFirst() throws {
        let storeSource = try sourceText(at: "ViewModels/RadixStoreDataEdit.swift")
        let methodSource = storeSource
            .components(separatedBy: "func removeDataEditPhrase(word: String) throws")[1]
            .components(separatedBy: "func removeAddedPhrases(words:")[0]
        let persistenceIndex = try #require(methodSource.range(of: "try phraseRepo.deletePhrase(word: storedWord)"))
        let publicationIndex = try #require(methodSource.range(of: "dataEditPhrases.removeAll"))
        let quickEditorSource = try sourceText(at: "App/QuickPhraseEditorView.swift")
        let addSheetSource = try sourceText(at: "Views/AddPhraseSheet.swift")

        #expect(persistenceIndex.lowerBound < publicationIndex.lowerBound)
        #expect(methodSource.contains("throw error"))
        #expect(quickEditorSource.contains("try store.removeDataEditPhrase(word: phraseEditorWord)"))
        #expect(quickEditorSource.contains("editorError = \"\\(action.confirmationTitle) failed:"))
        #expect(addSheetSource.contains("try store.removeDataEditPhrase(word: candidate.phrase)"))
        #expect(addSheetSource.contains("resultMessage = \"Delete failed:"))
    }

    @Test("Phrase context-menu deletion surfaces persistence failures")
    func phraseContextMenuDeletionUsesThrowingContract() throws {
        let source = try sourceText(at: "Views/CharacterContextMenus.swift")

        #expect(source.contains("try store.removeDataEditPhrase(word: trimmedWord)"))
        #expect(!source.contains("try? store.removeDataEditPhrase(word: trimmedWord)"))
        #expect(source.contains("deletionError = error.localizedDescription"))
        #expect(source.contains(".alert(\"Delete Failed\""))
    }

    @Test("Character quick editors keep essential actions visible")
    func characterQuickEditorsUseProtectedLargePresentation() throws {
        let sheetSource = try sourceText(at: "App/QuickEditSheets.swift")
        let editorSource = try sourceText(at: "App/QuickCharacterEditorView.swift")

        #expect(sheetSource.components(separatedBy: ".presentationDetents([.large])").count - 1 == 2)
        #expect(sheetSource.components(separatedBy: ".presentationDetents([.medium, .large])").count - 1 == 2)
        #expect(editorSource.components(separatedBy: ".fixedSize(horizontal: true, vertical: false)").count - 1 == 3)
    }

    @Test("Phrase inspection can return to the existing results")
    func phraseInspectionPreservesResultsNavigation() throws {
        let source = try sourceText(at: "Views/PhraseTableSheet.swift")

        #expect(source.contains("Label(\"Back to Phrases\", systemImage: \"chevron.backward\")"))
        #expect(source.contains("phraseTableExitButton"))
        #expect(source.contains(".scrollPosition(id: $phraseScrollPosition)"))
    }

    @Test("Text to Page does not read the clipboard on entry")
    func manualPageEntryStartsEmpty() throws {
        let captureSource = try sourceText(at: "App/CaptureTab.swift")
            .components(separatedBy: "private func beginManualCollection()")[1]
            .components(separatedBy: "private func saveManualCollection()")[0]
        let browseSource = try sourceText(at: "App/BrowseCollectionEditing.swift")
            .components(separatedBy: "func beginManualCollection()")[1]
            .components(separatedBy: "func beginBrowseImageFileImport()")[0]

        #expect(captureSource.contains("manualCollectionText = \"\""))
        #expect(browseSource.contains("manualCollectionText = \"\""))
        #expect(!captureSource.contains("pasteboard"))
        #expect(!browseSource.contains("clipboardText()"))
    }

    @Test("Capture recognition owns its task without owning later navigation")
    func captureRecognitionUsesOperationOwnership() throws {
        let source = try sourceText(at: "App/CaptureTab.swift")

        #expect(source.contains("@State private var recognitionTask: Task<Void, Never>?"))
        #expect(source.contains("recognitionTask?.cancel()"))
        #expect(source.contains("activeRecognitionID = operationID"))
        #expect(source.contains("guard activeRecognitionID == operationID, !Task.isCancelled else { return }"))
        #expect(source.contains("captureContextAllowsAutoOpen = false"))
        #expect(source.contains("CaptureCompletionNavigationPolicy.shouldAutoOpen("))
        #expect(source.contains("if shouldAutoOpen {"))
        #expect(source.contains("statusMessage = \"Page saved. Open it from Pages below.\""))
    }

    @Test("Shared imports have atomic ownership, idempotency, and recovery controls")
    func sharedImportsUseOwnedRecoverableQueue() throws {
        let queueSource = try sourceText(at: "Shared/RadixSharedImageImport.swift")
        let storeSource = try sourceText(at: "ViewModels/RadixStoreSharedImageImport.swift")
        let collectionsSource = try sourceText(at: "ViewModels/RadixStoreCollections.swift")
        let rootSource = try sourceText(at: "App/RootView.swift")

        #expect(queueSource.contains("try FileManager.default.moveItem(at: sourceURL, to: destinationURL)"))
        #expect(queueSource.contains("static func claimPendingItems()"))
        #expect(queueSource.contains("static func fail("))
        #expect(queueSource.contains("static func retry("))
        #expect(queueSource.contains("static func discard("))
        #expect(storeSource.contains("guard sharedImportTask == nil"))
        #expect(storeSource.contains("RadixSharedImageImport.claimPendingItems()"))
        #expect(storeSource.components(separatedBy: "id: item.id").count - 1 == 2)
        #expect(collectionsSource.contains("if let existing = collection(id: id)"))
        #expect(rootSource.contains(".alert(\"Shared Import Failed\""))
        #expect(rootSource.contains("Button(\"Retry\")"))
        #expect(rootSource.contains("Button(\"Discard\", role: .destructive)"))
    }

    @Test("Sentence list and editor publish favorite changes to mounted cards")
    func sentenceMutationsPublishSharedFavoriteRevision() throws {
        let rowSource = try sourceText(at: "App/FavouritesSentenceRows.swift")
            .components(separatedBy: "func toggleSentenceExampleFavorite(_ example:")[1]
            .components(separatedBy: "func presentSentenceExamplePracticeAgain")[0]
        let presentationSource = try sourceText(at: "App/FavouritesPresentations.swift")
        let lifecycleSource = try sourceText(at: "App/FavouritesTabLifecycle.swift")
        let headerSource = try sourceText(at: "Views/PhraseInfoHeader.swift")
        let storeSource = try sourceText(at: "ViewModels/RadixStore.swift")
        let rowPersistence = try #require(rowSource.range(of: "try RadixStudyPreferences.setSentenceExampleFavorite"))
        let rowPublication = try #require(rowSource.range(of: "store.favoriteSentenceRevision += 1"))
        let editPersistence = try #require(presentationSource.range(of: "try RadixStudyPreferences.replaceSentenceExample(updated)"))
        let editPublication = try #require(presentationSource.range(of: "store.favoriteSentenceRevision += 1"))

        #expect(rowPersistence.lowerBound < rowPublication.lowerBound)
        #expect(editPersistence.lowerBound < editPublication.lowerBound)
        #expect(storeSource.contains("@Published var favoriteSentenceRevision = 0"))
        #expect(lifecycleSource.contains(".onChange(of: store.favoriteSentenceRevision)"))
        #expect(headerSource.contains("try store.toggleFavoriteSentence(practiceItem)"))
        #expect(headerSource.contains("store.isFavoriteSentence(practiceItem)"))
    }

    @Test("Saved pages preserve valid Han characters beyond dictionary coverage")
    func savedPagesSeparateUnicodeValidityFromDictionaryCoverage() throws {
        let collectionSource = try sourceText(at: "ViewModels/RadixStoreCollections.swift")
        let sheetSource = try sourceText(at: "Views/BrowseCollectionSheets.swift")

        #expect(collectionSource.contains("guard validation.hasChineseCharacters else { return nil }"))
        #expect(collectionSource.contains("let characters = validation.charactersInReadingOrder"))
        #expect(!collectionSource.contains("allCharactersInOrder(in: sourceText).filter { componentRepo.hasCharacter($0) }"))
        #expect(sheetSource.contains("PageCharacterValidationSummary(validation: characterValidation)"))
        #expect(sheetSource.contains("do not have Radix dictionary details"))
        #expect(sheetSource.contains("They will still be kept on this saved page."))
    }

    @Test("Data-backed capture propagates metadata orientation to preview, OCR, and thumbnails")
    func capturedImageUsesMetadataOrientation() throws {
        let imageSource = try sourceText(at: "Services/CapturedImage.swift")
        let ocrSource = try sourceText(at: "Services/CaptureOCRService.swift")
        let thumbnailSource = try sourceText(at: "Services/CaptureImageIO.swift")

        #expect(imageSource.contains("orientation ?? properties?.orientation ?? .up"))
        #expect(!imageSource.contains("orientation: CGImagePropertyOrientation = .up"))
        #expect(ocrSource.contains("orientation: image.orientation"))
        #expect(thumbnailSource.contains("applyOrientationTransform: true"))
        #expect(thumbnailSource.contains("kCGImageSourceCreateThumbnailWithTransform: applyOrientationTransform"))
    }

    @Test("Image imports enforce a pre-decode budget and Vision receives bounded data")
    func imageImportsEnforceResourceBudget() throws {
        let imageSource = try sourceText(at: "Services/CapturedImage.swift")
        let loaderSource = try sourceText(at: "Services/CaptureImageIO.swift")
        let sharedImportSource = try sourceText(at: "ViewModels/RadixStoreSharedImageImport.swift")
        let ocrSource = try sourceText(at: "Services/CaptureOCRService.swift")

        let validation = try #require(imageSource.range(of: "CaptureImageResourceValidator.validate("))
        let preview = try #require(imageSource.range(of: "UIImage(data: boundedData)"))
        #expect(validation.lowerBound < preview.lowerBound)
        #expect(imageSource.contains("CaptureImageResourceBudget.requiresDownsampling"))
        #expect(imageSource.contains("maximumRecognitionDimension"))
        #expect(imageSource.contains("image.preparingThumbnail(of: targetSize)"))
        #expect(loaderSource.contains("validateFileSize(at: url)"))
        #expect(loaderSource.contains("Data(contentsOf: url, options: .mappedIfSafe)"))
        #expect(loaderSource.contains("FileRepresentation(importedContentType: .image)"))
        #expect(loaderSource.contains("validateFileSize(at: received.file)"))
        #expect(loaderSource.contains("try Task.checkCancellation()"))
        #expect(sharedImportSource.contains("validateFileSize(at: item.fileURL)"))
        #expect(sharedImportSource.contains("Data(contentsOf: item.fileURL, options: .mappedIfSafe)"))
        #expect(ocrSource.contains("try Task.checkCancellation()"))
        #expect(ocrSource.contains("data: image.data"))
    }

    @Test("Image OCR requires disclosed consent before Gemini fallback")
    func imageOCRSeparatesLocalOutcomesFromCloudRetry() throws {
        let storeSource = try sourceText(at: "ViewModels/RadixStoreImageOCR.swift")
        let captureSource = try sourceText(at: "App/CaptureTab.swift")
        let browseSource = try sourceText(at: "App/BrowseCollectionEditing.swift")
        let browseRootSource = try sourceText(at: "App/FilterGridTab.swift")
        let sharedImportSource = try sourceText(at: "ViewModels/RadixStoreSharedImageImport.swift")

        #expect(storeSource.contains("func recognizeImageTextLocally"))
        #expect(storeSource.contains("return .failed(error.localizedDescription)"))
        #expect(storeSource.contains("func recognizeImageTextWithGemini"))
        #expect(!storeSource.contains("recognizeImageTextWithAIFallback"))
        #expect(captureSource.contains("Trying Gemini sends this image to Google's Gemini service."))
        #expect(captureSource.contains("beginRecognition(request.image, source: request.source, method: .gemini)"))
        #expect(browseRootSource.contains(".alert(item: $presentedBrowseAlert, content: browseAlert)"))
        #expect(browseSource.contains("Trying Gemini sends this image to Google's Gemini service."))
        #expect(browseSource.contains("recognizeBrowseImage(request.image, method: .gemini)"))
        #expect(browseSource.contains("let localResult = try await store.recognizeImageTextLocally"))
        #expect(sharedImportSource.contains("let localResult = try await recognizeImageTextLocally"))
        #expect(!sharedImportSource.contains("recognizeImageTextWithGemini"))
    }

    @Test("AI prompt tests cancel and reject stale task or source completion")
    func promptTestsOwnTheirRequestContext() throws {
        let viewSource = try sourceText(at: "Views/AILinkView.swift")
        let generationSource = try sourceText(at: "Views/AILinkPromptGeneration.swift")

        #expect(viewSource.contains("@State var promptTestTask: Task<Void, Never>?"))
        #expect(viewSource.contains("@State var activePromptTestRequestID: UUID?"))
        #expect(viewSource.contains(".onChange(of: promptTestSelectionIdentity)"))
        #expect(viewSource.contains("promptTestTask?.cancel()"))
        #expect(viewSource.contains("activePromptTestRequestID = nil"))
        #expect(generationSource.contains("let request = makePromptTestRequest()"))
        #expect(generationSource.contains("promptTestTask?.cancel()"))
        #expect(generationSource.contains("guard acceptsPromptTestCompletion(request), !Task.isCancelled else { return }"))
        #expect(generationSource.contains("PromptTestCompletionPolicy.accepts("))
        #expect(generationSource.contains("Result: \\(promptTestOutputContext.taskTitle) | Source: \\(promptTestOutputContext.sourceTitle)"))
    }

    private func sourceText(at relativePath: String) throws -> String {
        let testFileURL = URL(fileURLWithPath: #filePath)
        let repositoryURL = testFileURL
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        return try String(
            contentsOf: repositoryURL.appendingPathComponent(relativePath),
            encoding: .utf8
        )
    }
}
