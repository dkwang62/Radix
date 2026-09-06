import SwiftUI

extension FavouritesTab {
    func studyPresentations<Content: View>(_ content: Content) -> some View {
        content
            .sheet(item: phonePhraseSheetBinding) { phrase in
                NavigationStack {
                    PhraseInfoCard(phrase: phrase, onDone: {
                        selectedPhrase = nil
                    })
                    .environmentObject(store)
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(item: $screenState.conversationPractice.reviewPresentation, onDismiss: {
                conversationPracticeReviewPresentation = nil
                refreshConversationPracticeProgress()
            }) { presentation in
                ConversationPracticeReviewSheet(
                    library: presentation.library,
                    usesTraditionalScript: $screenState.navigation.usesTraditionalScript
                )
                .environmentObject(store)
                .environmentObject(entitlement)
                .presentationDetents([.large])
            }
            .sheet(item: $screenState.conversationPractice.quizPresentation, onDismiss: {
                conversationPracticeQuizPresentation = nil
                refreshConversationPracticeProgress()
            }) { presentation in
                ConversationPracticeQuizSheet(
                    library: presentation.library,
                    usesTraditionalScript: $screenState.navigation.usesTraditionalScript
                )
                .environmentObject(store)
                .environmentObject(entitlement)
                .presentationDetents([.large])
            }
            .sheet(item: $screenState.pages.translationReportCollection) { collection in
                BrowseTranslationReportSheet(
                    collectionName: collection.name,
                    report: $screenState.pages.translationReportDraft,
                    updatedAt: collection.translationReportUpdatedAt,
                    onPaste: pasteStudyTranslationReport,
                    onSave: { saveStudyTranslationReport(collection) },
                    onClear: { clearStudyTranslationReport(collection) },
                    onDone: { studyTranslationReportCollection = nil }
                )
            }
            .sheet(item: $screenState.pages.phrasesPresentation) { presentation in
                PhraseTableSheet(
                    character: presentation.collection.characters.joined(),
                    isVertical: isPhone,
                    fixedPhrases: presentation.phrases,
                    fixedTitle: "Page Phrases",
                    fixedScopeLabel: presentation.collection.name,
                    fixedSort: .pinyin,
                    keepsPhraseInspectionInSheet: true,
                    returnTitle: "Back to Study Page"
                )
                .environmentObject(store)
            }
            .sheet(item: $screenState.sentences.editDraft) { draft in
                SentenceExampleEditSheet(record: draft.record) { updated in
                    try RadixStudyPreferences.replaceSentenceExample(updated)
                    store.favoriteSentenceRevision += 1
                    sentenceExampleRevision += 1
                    sentenceExampleStatusMessage = "Updated"
                    loadFavoriteSentences()
                    refreshSentenceExampleResults()
                    sentenceExampleEditDraft = nil
                }
            }
            .sheet(isPresented: $screenState.navigation.showsCheckpoints) {
                NavigationStack {
                    ScrollView {
                        studyCheckpointsSection
                            .padding()
                    }
                    .navigationTitle("Checkpoints")
                    .navigationBarTitleDisplayMode(.inline)
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button("Done") {
                                showStudyCheckpoints = false
                            }
                        }
                    }
                }
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $screenState.conversationPractice.showsPasteImporter) {
                ConversationPracticePasteImportSheet { pack in
                    importPastedConversationPracticePack(pack)
                }
                .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $screenState.conversationPractice.showsImporter,
                allowedContentTypes: [RadixFileTypes.json],
                allowsMultipleSelection: false
            ) { result in
                importConversationPracticePack(result)
            }
            .fileExporter(
                isPresented: $screenState.sentences.showsExporter,
                document: sentenceDatabaseExportDocument,
                contentType: RadixFileTypes.database,
                defaultFilename: sentenceDatabaseExportFilename
            ) { result in
                isRunningSentenceDatabaseTransfer = false
                switch result {
                case .success:
                    sentenceExampleStatusMessage = "Exported sentence database."
                case .failure(let error):
                    sentenceExampleStatusMessage = "Export failed: \(error.localizedDescription)"
                }
            }
            .fileImporter(
                isPresented: $screenState.sentences.showsImporter,
                allowedContentTypes: RadixFileTypes.sentenceDatabaseImports,
                allowsMultipleSelection: false
            ) { result in
                prepareSentenceDatabaseImport(result)
            }
            .alert("Return to Checkpoint?", isPresented: Binding(
                get: { pendingCheckpointReturn != nil },
                set: { if !$0 { pendingCheckpointReturn = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    pendingCheckpointReturn = nil
                }
                Button("Return to Checkpoint", role: .destructive) {
                    let checkpoint = pendingCheckpointReturn
                    pendingCheckpointReturn = nil
                    onReturnToCheckpoint(checkpoint)
                }
            } message: {
                Text("Current study data on this device will be replaced by the selected checkpoint. Backup files are not affected.")
            }
            .alert("Delete Practice?", isPresented: Binding(
                get: { pendingConversationPracticeDeletion != nil },
                set: { if !$0 { pendingConversationPracticeDeletion = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    pendingConversationPracticeDeletion = nil
                }
                Button("Delete Practice", role: .destructive) {
                    guard let topic = pendingConversationPracticeDeletion else { return }
                    pendingConversationPracticeDeletion = nil
                    deleteConversationPracticeTopic(topic)
                }
            } message: {
                Text("This removes the imported practice set from this device.")
            }
            .alert("Replace Practice?", isPresented: Binding(
                get: { pendingConversationPracticeReplacement != nil },
                set: { if !$0 { pendingConversationPracticeReplacement = nil } }
            )) {
                Button("Cancel", role: .cancel) {
                    pendingConversationPracticeReplacement = nil
                }
                Button("Replace Practice", role: .destructive) {
                    guard let review = pendingConversationPracticeReplacement else { return }
                    pendingConversationPracticeReplacement = nil
                    finishImportingConversationPracticePack(review.pack, replacing: true)
                }
            } message: {
                Text(pendingConversationPracticeReplacement?.message ?? "")
            }
            .modifier(SentenceExampleDeletionAlert(
                pendingDeletion: $screenState.sentences.pendingDeletion,
                onDelete: { record in
                    deleteSentenceExamples([record], statusMessage: "Deleted")
                }
            ))
            .alert("Delete Matching Sentences?", isPresented: $screenState.sentences.showsDeleteFilteredConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button(sentenceExampleBulkDeleteConfirmationTitle, role: .destructive) {
                    deleteFilteredSentenceExamples()
                }
            } message: {
                Text(sentenceExampleBulkDeleteMessage)
            }
            .alert("Delete Selected Sentences?", isPresented: $screenState.sentences.showsDeleteSelectedConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button(sentenceExampleSelectedDeleteConfirmationTitle, role: .destructive) {
                    deleteSelectedSentenceExamples()
                }
            } message: {
                Text("This permanently deletes only the selected sentences shown in Study.")
            }
            .alert("Import Saved Sentences?", isPresented: Binding(
                get: { pendingSentenceDatabaseImport != nil },
                set: { _ in }
            )) {
                Button("Cancel", role: .cancel) {
                    clearPendingSentenceDatabaseImport()
                }
                Button("Merge") {
                    importPendingSentenceDatabase(mode: .additive)
                }
                Button("Replace", role: .destructive) {
                    importPendingSentenceDatabase(mode: .complete)
                }
            } message: {
                Text("Merge adds new sentences and updates matching ones. Replace swaps your saved sentences with this file after creating a recovery copy.")
            }
            .alert("Clear Saved Sentences?", isPresented: $screenState.sentences.showsClearConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button("Clear Saved Sentences", role: .destructive) {
                    clearSentenceDatabase()
                }
            } message: {
                Text("This deletes all saved sentences from Study. Pages, phrases, and practices are not deleted. Radix creates a recovery copy first.")
            }
            .alert("Delete Saved Page?", isPresented: Binding(
                get: { pendingStudyDeleteCollection != nil },
                set: { if !$0 { pendingStudyDeleteCollection = nil } }
            )) {
                Button("Delete", role: .destructive) {
                    if let collection = pendingStudyDeleteCollection {
                        store.deleteCollection(id: collection.id)
                    }
                    pendingStudyDeleteCollection = nil
                }
                Button("Cancel", role: .cancel) {
                    pendingStudyDeleteCollection = nil
                }
            } message: {
                if let collection = pendingStudyDeleteCollection {
                    Text(store.deletionImpact(for: collection).alertMessage)
                }
            }
            .alert("Promote Corrected OCR?", isPresented: Binding(
                get: { pendingStudyOCRPromotion != nil },
                set: { if !$0 { pendingStudyOCRPromotion = nil } }
            )) {
                Button("Promote, Keep Original") {
                    promotePendingOCRCorrection(keepOriginal: true)
                }
                Button("Promote, Delete Original", role: .destructive) {
                    promotePendingOCRCorrection(keepOriginal: false)
                }
                Button("Cancel", role: .cancel) {
                    pendingStudyOCRPromotion = nil
                }
            } message: {
                if let promotion = pendingStudyOCRPromotion {
                    Text("Use \"\(promotion.corrected.name)\" as the main page for \"\(promotion.original.name)\". Existing page-linked practice, translation, favorites, and progress stay with the main page.")
                }
            }
            .alert(item: $screenState.pages.aiFallbackTask) { task in
                Alert(
                    title: Text(PageAIMethodCopy.unavailableTitle),
                    message: Text("\(studyAutomaticAIError)\n\n\(PageAIMethodCopy.unavailableMessage)"),
                    primaryButton: .default(Text(PageAIMethodCopy.fallbackTitle)) {
                        useManualStudyAIFallback(task)
                    },
                    secondaryButton: .cancel(Text("Not Now"))
                )
            }
    }
}
