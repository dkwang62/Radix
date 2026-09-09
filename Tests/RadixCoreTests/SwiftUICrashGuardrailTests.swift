import Foundation
import Testing

@Suite("SwiftUI crash guardrails")
struct SwiftUICrashGuardrailTests {
    @Test("Page deletion recovers before startup and publishes only after the journal completes")
    func pageDeletionRecoveryWiring() throws {
        let lifecycle = try sourceText(at: "ViewModels/RadixStoreLifecycle.swift")
        let recovery = try #require(lifecycle.range(of: "try recoverPendingPageDeletion()"))
        let preprocessing = try #require(lifecycle.range(of: "preprocessStoredAICleanedPagesIfNeeded()"))
        #expect(recovery.lowerBound < preprocessing.lowerBound)
        let collections = try sourceText(at: "ViewModels/RadixStoreCollections.swift")
        let deletion = collections.components(separatedBy: "func deleteCollection(id: UUID) async throws {")[1]
            .components(separatedBy: "var pageDeletionJournal:")[0]
        let commit = try #require(deletion.range(of: "try journal.commit(prepared)"))
        let publication = try #require(deletion.range(of: "allCollections.removeAll"))
        #expect(commit.lowerBound < publication.lowerBound)
        #expect(collections.contains("pageDeletionDeferralCount == 0"))
        #expect(deletion.components(separatedBy: "try requirePageDeletionAvailable()").count == 3)
        #expect(deletion.contains("try await Task.detached(priority: .userInitiated)"))
        #expect(deletion.contains("try Task.checkCancellation()"))
        #expect(deletion.contains("dataImportRevision == importRevision"))
        #expect(deletion.contains("defer { isPreparingPageDeletion = false }"))
        let root = try sourceText(at: "App/RootView.swift")
        #expect(root.contains("if let error = store.pageDeletionRecoveryError"))
        #expect(root.contains("Button(\"Retry\") { Task { await store.initialize() } }"))
        let imports = try sourceText(at: "ViewModels/RadixStoreDataImport.swift")
        for signature in ["func importPortableBackupDocumentForRestore", "func importSentenceLibraryPackage", "func importSentenceDatabase"] {
            let body = imports.components(separatedBy: signature)[1].components(separatedBy: "\n    }")[0]
            #expect(body.contains("try pageDeletionJournal.requireNoPendingDeletion()"))
            #expect(body.contains("defer { pageDeletionDeferralCount -= 1 }"))
        }
    }

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

    @Test("Startup failures preserve retry and recovery destinations")
    func startupFailuresKeepRecoveryAccessible() throws {
        let lifecycleSource = try sourceText(at: "ViewModels/RadixStoreLifecycle.swift")
        let detailSource = try sourceText(at: "App/RootDetailPane.swift")
        let phoneSource = try sourceText(at: "App/RootPhoneView.swift")

        #expect(lifecycleSource.components(separatedBy: "loadingError = nil").count - 1 >= 2)
        #expect(detailSource.contains("if let error = store.loadingError, !isStartupRecoveryDestination"))
        #expect(detailSource.contains("store.route == .settings || (store.route == .search && store.homeTab == .dataEdit)"))
        #expect(detailSource.contains("Button(\"Retry\")"))
        #expect(detailSource.contains("Button(\"My Data\")"))
        #expect(detailSource.contains("Button(\"Settings\")"))
        #expect(phoneSource.contains("if let error = store.loadingError, !isStartupRecoveryDestination"))
    }

    @Test("Sentence AI completion remains owned by its source sentence")
    func sentenceAICompletionUsesSourceIdentity() throws {
        let cardSource = try sourceText(at: "Views/PhraseInfoCard.swift")
        let sentenceSource = try sourceText(at: "Views/PhraseInfoSentence.swift")
        let headerSource = try sourceText(at: "Views/PhraseInfoHeader.swift")
        let controlsSource = try sourceText(at: "Views/PhraseInfoControls.swift")

        #expect(cardSource.contains("@State var sentenceAITask: Task<Void, Never>?"))
        #expect(cardSource.contains(".onChange(of: sentenceSourceID)"))
        #expect(cardSource.contains("cancelSentenceAIWork()"))
        #expect(sentenceSource.components(separatedBy: "guard acceptsSentenceAICompletion(requestID: requestID, sentenceID: item.id) else { return }").count - 1 == 4)
        #expect(sentenceSource.contains("activeSentenceAIRequestID == requestID && sentenceSourceID == sentenceID"))
        #expect(headerSource.contains("if let practiceItem = practiceSentenceItem"))
        #expect(controlsSource.contains("for: practiceSentenceItem"))
        #expect(controlsSource.contains("usesTraditionalScript: sentenceUsesTraditionalScript"))
    }

    @Test("Quiz script changes cannot score one item twice")
    func quizScoringUsesStableItemIdentity() throws {
        let source = try sourceText(at: "App/ConversationPracticeQuizSheet.swift")
        let chooseSource = source
            .components(separatedBy: "func choose(_ choice: String)")[1]
            .components(separatedBy: "func advance()")[0]
        let scriptSource = source
            .components(separatedBy: "func changeQuizScript(_ scriptFilter: ScriptFilter)")[1]
            .components(separatedBy: "private func makeRound")[0]

        #expect(source.contains("answered[currentItem.id] != nil"))
        #expect(chooseSource.contains("guard answered[currentItem.id] == nil else { return }"))
        #expect(chooseSource.contains("answered[currentItem.id] = choice == quizCharacter"))
        #expect(!chooseSource.contains("quizCharacter]"))
        #expect(!scriptSource.contains("selectedAnswerID = nil"))
    }

    @Test("Backup phrase reversion confirms the exact displayed set")
    func backupPhraseReversionUsesConfirmedDisplayedSet() throws {
        let sectionSource = try sourceText(at: "App/DataBackupPreviewSection.swift")
        let actionSource = try sourceText(at: "App/DataBackupPreviewActions.swift")
        let storeSource = try sourceText(at: "ViewModels/RadixStoreDataEdit.swift")

        #expect(sectionSource.contains(".alert(\"Revert Edited Phrases?\""))
        #expect(sectionSource.contains("pendingBasePhraseRevertWords.count"))
        #expect(actionSource.contains("pendingBasePhraseRevertWords = basePhraseCoreEditEntries"))
        #expect(actionSource.contains("store.removeUnnotedBasePhraseEdits(words: words)"))
        #expect(storeSource.contains("func removeUnnotedBasePhraseEdits(words: [String]) throws"))
        #expect(storeSource.contains("try createDatabaseSafetySnapshots(reason: \"Before reverting edited phrases\")"))
        #expect(storeSource.contains("eligibleWords.contains($0) && seenWords.insert($0).inserted"))
    }

    @Test("Translation Clear remains a draft-only edit")
    func translationClearDoesNotPersistBeforeSave() throws {
        let browseSource = try sourceText(at: "App/BrowseImageActions.swift")
        let studySource = try sourceText(at: "App/FavouritesStudyGridData.swift")
        let sheetSource = try sourceText(at: "Views/BrowseTranslationReportSheet.swift")
        let browseClearSource = browseSource
            .components(separatedBy: "func clearTranslationReport()")[1]
            .components(separatedBy: "func runBrowseGeminiPhraseExtraction")[0]
        let studyClearSource = studySource
            .components(separatedBy: "func clearStudyTranslationReport()")[1]
            .components(separatedBy: "func beginPromotingOCRCorrection")[0]

        #expect(browseClearSource.contains("translationReportDraft = \"\""))
        #expect(!browseClearSource.contains("updateCollectionTranslationReport"))
        #expect(studyClearSource.contains("studyTranslationReportDraft = \"\""))
        #expect(!studyClearSource.contains("updateCollectionTranslationReport"))
        #expect(sheetSource.contains("Button(\"Save\", action: onSave)"))
        #expect(sheetSource.components(separatedBy: ".disabled(trimmedReport.isEmpty)").count - 1 == 1)
    }

    @Test("Sentence search preserves source scope and distinguishes filtered emptiness")
    func sentenceSearchKeepsScopeAndTruthfulEmptyState() throws {
        let controlsSource = try sourceText(at: "App/FavouritesSentenceControls.swift")
        let searchObserver = controlsSource
            .components(separatedBy: ".onChange(of: sentenceExampleSearchText)")[1]
            .components(separatedBy: ".onChange(of: sentenceExampleMinimumCharacterCount)")[0]
        let dataSource = try sourceText(at: "App/FavouritesSentenceData.swift")
        let sectionSource = try sourceText(at: "App/FavouritesSections.swift")
        let stateSource = try sourceText(at: "App/FavouritesStudyScreenState.swift")

        #expect(!searchObserver.contains("sentenceExampleFilter = .all"))
        #expect(searchObserver.contains("resetSentenceExampleResultsContext()"))
        #expect(stateSource.contains("var libraryCount = 0"))
        #expect(dataSource.contains("sentenceExampleLibraryCount = RadixStudyPreferences.sentenceExampleCount()"))
        #expect(dataSource.contains("func resetSentenceExampleFilters()"))
        #expect(sectionSource.contains("if sentenceExampleLibraryCount == 0"))
        #expect(sectionSource.contains("Label(\"No Matching Sentences\""))
        #expect(sectionSource.contains("Button(\"Reset Filters\", action: resetSentenceExampleFilters)"))
    }

    @Test("AI task changes require an explicit unsaved-draft decision")
    func aiTemplateDraftChangesAreGuarded() throws {
        let viewSource = try sourceText(at: "Views/AILinkView.swift")
        let generationSource = try sourceText(at: "Views/AILinkPromptGeneration.swift")

        #expect(viewSource.contains("enum PendingPromptDraftAction"))
        #expect(viewSource.contains(".alert(\"Unsaved AI Template Changes\""))
        #expect(viewSource.contains("Button(\"Save and Continue\")"))
        #expect(viewSource.contains("Button(\"Discard Changes\", role: .destructive)"))
        #expect(viewSource.contains("Button(\"Cancel\", role: .cancel)"))
        #expect(viewSource.contains("guard hasUnsavedPromptChanges else"))
        #expect(viewSource.contains("requestPromptDraftAction(.openTemplateManager)"))
        #expect(generationSource.components(separatedBy: "requestPromptDraftAction(.openTemplateManager)").count - 1 == 2)
        #expect(generationSource.contains("requestSelectPromptTask(task.id)"))
        #expect(generationSource.contains("requestCreateCustomPromptTask()"))
    }

    @Test("Phrase classification keeps controls fixed around a scrolling grid")
    func phraseClassificationHasVerticalOverflowEscape() throws {
        let source = try sourceText(at: "App/AddedPhraseReviewGrid.swift")
        let gridContainerSource = source
            .components(separatedBy: "var phraseGrid: some View")[1]
            .components(separatedBy: "@ViewBuilder")[0]
        let pageGridSource = source
            .components(separatedBy: "var phrasePageGrid: some View")[1]
            .components(separatedBy: "var phrasePageGridContent: some View")[0]

        #expect(gridContainerSource.contains("phrasePageGrid"))
        #expect(gridContainerSource.contains("pageFooter"))
        #expect(pageGridSource.contains("ScrollView(.vertical)"))
        #expect(pageGridSource.contains(".scrollBounceBehavior(.basedOnSize)"))
        #expect(pageGridSource.contains(".frame(maxWidth: .infinity, maxHeight: .infinity)"))
    }

    @Test("Example sheets page exact matches off the presentation path and refresh after mutations")
    func sentenceExampleSheetsOwnPagedRefreshableQueries() throws {
        let sheetSource = try sourceText(at: "Views/SentenceExampleListSheet.swift")
        let characterSource = try sourceText(at: "Views/CharacterInfoCard.swift")
        let phraseSource = try sourceText(at: "Views/PhraseInfoCard.swift")
        let preferencesSource = try sourceText(at: "Services/RadixStudyPreferences.swift")

        #expect(characterSource.contains("lookup: .character(item.character)"))
        #expect(phraseSource.contains("lookup: .phrase(phrase.word)"))
        #expect(!characterSource.contains("limit: nil"))
        #expect(!phraseSource.contains("limit: nil"))
        #expect(sheetSource.contains("Task.detached(priority: .userInitiated)"))
        #expect(sheetSource.contains("store.favoriteSentenceRevision"))
        #expect(sheetSource.contains("ContentUnavailableView"))
        #expect(sheetSource.contains(".task(id: nextOffset)"))
        #expect(preferencesSource.contains("static func sentenceExamplePage("))
        #expect(preferencesSource.contains("let nextOffset = queryOffset + index + 1"))
    }

    @Test("Core study text scales and compact controls preserve touch targets")
    func coreStudySurfacesRespectDynamicType() throws {
        let fontSource = try sourceText(at: "Models/ResponsiveFont.swift")
        let rootSupportSource = try sourceText(at: "App/RootViewSupport.swift")
        let phraseCardSource = try sourceText(at: "Views/PhraseInfoCard.swift")
        let phraseHeaderSource = try sourceText(at: "Views/PhraseInfoHeader.swift")
        let sentenceSource = try sourceText(at: "Views/PhraseInfoSentence.swift")
        let examplesSource = try sourceText(at: "Views/SentenceExampleListSheet.swift")
        let reviewSheetSource = try sourceText(at: "App/AddedPhraseReviewSheet.swift")
        let reviewGridSource = try sourceText(at: "App/AddedPhraseReviewGrid.swift")
        let reviewControlsSource = try sourceText(at: "App/AddedPhraseReviewControls.swift")

        #expect(fontSource.contains("public static let scalableCaption = Font.caption"))
        #expect(fontSource.contains("public static let scalableCaption2 = Font.caption2"))
        #expect(fontSource.contains("public static let caption = Font.system(size: 13)"))
        #expect(rootSupportSource.contains("struct CompactScriptToggle"))
        #expect(rootSupportSource.contains("ResponsiveFont.scalableCaption.weight(.semibold)"))
        #expect(rootSupportSource.contains(".radixMinimumTapTarget()"))
        #expect(phraseCardSource.contains("@Environment(\\.dynamicTypeSize) var dynamicTypeSize"))
        #expect(phraseHeaderSource.contains(".lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 1)"))
        #expect(sentenceSource.contains(".font(.system(.title, design: .rounded, weight: .bold))"))
        #expect(examplesSource.contains(".lineLimit(dynamicTypeSize.isAccessibilitySize ? nil : 2)"))
        #expect(examplesSource.contains("ResponsiveFont.scalableCaption"))
        #expect(!examplesSource.contains(".minimumScaleFactor(0.86)"))
        #expect(reviewSheetSource.contains("dynamicTypeSize.isAccessibilitySize ? 64"))
        #expect(reviewSheetSource.contains("ResponsiveFont.scalableCaption"))
        #expect(reviewGridSource.contains(".font(ResponsiveFont.body.weight(.semibold))"))
        #expect(reviewGridSource.contains(".lineLimit(2)"))
        #expect(reviewControlsSource.contains("if dynamicTypeSize.isAccessibilitySize { return 1 }"))
        #expect(reviewControlsSource.contains("RadixControlMetrics.standardHeight"))
    }

    @Test("Navigation, pages, and recovery actions use one user-facing vocabulary")
    func userFacingVocabularyRemainsConsistent() throws {
        let copySource = try sourceText(at: "App/RadixIconography.swift")
        let phoneSource = try sourceText(at: "App/RootPhoneView.swift")
        let detailSource = try sourceText(at: "App/RootDetailPane.swift")
        let navigationSource = try sourceText(at: "App/RootViewSupport.swift")
        let pageEditorSource = try sourceText(at: "Views/BrowseCollectionSheets.swift")
        let settingsSource = try sourceText(at: "Views/SettingsView.swift")
        let glossarySource = try sourceText(at: "Views/GlossaryView.swift")

        #expect(copySource.contains("static let myData = String(localized: \"My Data\")"))
        #expect(copySource.contains("static let safetyCopy = String(localized: \"Safety Copy\")"))
        #expect(copySource.contains("static let safetyCopies = String(localized: \"Safety Copies\")"))
        #expect(phoneSource.contains("return \"\\(RadixCopy.myData) -"))
        #expect(detailSource.contains("return \"\\(RadixCopy.myData) -"))
        #expect(navigationSource.contains("title: RadixCopy.myData"))
        #expect(navigationSource.contains("Section(RadixCopy.myData)"))
        #expect(pageEditorSource.components(separatedBy: "Section(RadixCopy.savedPage)").count == 3)
        #expect(!pageEditorSource.contains("Section(\"Image\")"))
        #expect(settingsSource.contains("Label(RadixCopy.safetyCopies"))
        #expect(settingsSource.contains("Checkpoints, safety copies, and API keys are kept."))
        #expect(!settingsSource.contains("Recovery Copies"))
        #expect(!settingsSource.contains("Device snapshots"))
        #expect(glossarySource.contains("term: \"Safety Copy\""))
        #expect(!glossarySource.contains("term: \"Recovery Copies\""))
    }

    @Test("Upgrade supports retry, pending purchases, and one StoreKit operation at a time")
    func paywallStoreOperationsRemainRecoverable() throws {
        let managerSource = try sourceText(at: "Services/EntitlementManager.swift")
        let paywallSource = try sourceText(at: "Views/PaywallView.swift")
        let plansSource = try sourceText(at: "Views/PaywallPlans.swift")
        let footerSource = try sourceText(at: "Views/PaywallFooter.swift")

        #expect(managerSource.contains("enum PurchaseOutcome: Equatable"))
        #expect(managerSource.contains("case pending"))
        #expect(managerSource.contains("case cancelled"))
        #expect(managerSource.contains("activePurchaseProductID == nil, !isRestoringPurchases"))
        #expect(managerSource.contains("func restorePurchases() async -> RestoreOutcome"))
        #expect(managerSource.contains("case noPurchases"))
        #expect(paywallSource.contains("if entitlement.products.isEmpty"))
        #expect(paywallSource.contains("await entitlement.loadProducts()"))
        #expect(paywallSource.contains("finishPendingPurchaseIfUnlocked()"))
        #expect(plansSource.contains("Retry Loading Plans"))
        #expect(plansSource.contains("Purchase awaiting approval."))
        #expect(plansSource.contains(".disabled(storeOperationInProgress || pendingPurchaseID == product.id)"))
        #expect(footerSource.contains("No active Radix purchases were found for this Apple ID."))
        #expect(footerSource.contains(".disabled(storeOperationInProgress)"))
    }

    @Test("Learning-tier guide remains an anchored popover on compact phones")
    func learningTierGuideAvoidsUndismissableCompactSheet() throws {
        let headerSource = try sourceText(at: "Views/CharacterInfoCardHeader.swift")
        let tierPopover = try #require(
            headerSource.components(separatedBy: ".popover(isPresented: $showFrequencyGuide").last
        )
        let tierPopoverBody = try #require(tierPopover.components(separatedBy: "\n        }").first)

        #expect(tierPopoverBody.contains("tierGuideView"))
        #expect(tierPopoverBody.contains(".applyCompactPopoverStyle()"))
    }

    @Test("Full backup restore persists rollback intent and recovers before startup publication")
    func fullRestoreRollbackWiring() throws {
        let restore = try sourceText(at: "ViewModels/RadixStoreDataImport.swift")
        let lifecycle = try sourceText(at: "ViewModels/RadixStoreLifecycle.swift")
        let root = try sourceText(at: "App/RootView.swift")
        let begin = try #require(restore.range(of: "restoreRollbackJournal.begin"))
        let apply = try #require(restore.range(of: "try await applyPortableBackupDocument(document, mode: mode)"))
        let finish = try #require(restore.range(of: "try restoreRollbackJournal.finish()"))
        #expect(begin.lowerBound < apply.lowerBound)
        #expect(apply.lowerBound < finish.lowerBound)
        #expect(restore.contains("try await recoverPendingRestoreRollback()"))
        #expect(restore.contains("try flushRestorePersistence()"))

        let recovery = try #require(lifecycle.range(of: "try await recoverPendingRestoreRollback()"))
        let preprocessing = try #require(lifecycle.range(of: "preprocessStoredAICleanedPagesIfNeeded()"))
        #expect(recovery.lowerBound < preprocessing.lowerBound)
        #expect(root.contains("Recover Interrupted Restore"))
        #expect(root.contains("store.restoreRollbackRecoveryError"))
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
