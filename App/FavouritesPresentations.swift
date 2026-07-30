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
            .sheet(item: $conversationPracticeReviewPresentation, onDismiss: {
                conversationPracticeReviewPresentation = nil
                refreshConversationPracticeProgress()
            }) { presentation in
                ConversationPracticeReviewSheet(
                    library: presentation.library,
                    usesTraditionalScript: $studyGridUsesTraditionalScript
                )
                .environmentObject(store)
                .environmentObject(entitlement)
                .presentationDetents([.large])
            }
            .sheet(item: $conversationPracticeQuizPresentation, onDismiss: {
                conversationPracticeQuizPresentation = nil
                refreshConversationPracticeProgress()
            }) { presentation in
                ConversationPracticeQuizSheet(
                    library: presentation.library,
                    usesTraditionalScript: $studyGridUsesTraditionalScript
                )
                .environmentObject(store)
                .environmentObject(entitlement)
                .presentationDetents([.large])
            }
            .sheet(item: $studyTranslationReportCollection) { collection in
                BrowseTranslationReportSheet(
                    collectionName: collection.name,
                    report: $studyTranslationReportDraft,
                    updatedAt: collection.translationReportUpdatedAt,
                    onPaste: pasteStudyTranslationReport,
                    onSave: { saveStudyTranslationReport(collection) },
                    onClear: { clearStudyTranslationReport(collection) },
                    onDone: { studyTranslationReportCollection = nil }
                )
            }
            .sheet(item: $studyPagePhrasesPresentation) { presentation in
                PhraseTableSheet(
                    character: presentation.collection.characters.joined(),
                    isVertical: isPhone,
                    fixedPhrases: presentation.phrases,
                    fixedTitle: "Page Phrases",
                    fixedScopeLabel: presentation.collection.name,
                    fixedSort: .pinyin,
                    dismissesOnPhraseSelection: true,
                    returnTitle: "Back to Study"
                )
                .environmentObject(store)
            }
            .sheet(item: $sentenceExampleEditDraft) { draft in
                SentenceExampleEditSheet(record: draft.record) { updated in
                    RadixStudyPreferences.replaceSentenceExample(updated)
                    sentenceExampleRevision += 1
                    sentenceExampleStatusMessage = "Updated"
                    loadFavoriteSentences()
                    refreshSentenceExampleResults()
                    sentenceExampleEditDraft = nil
                }
            }
            .sheet(isPresented: $showStudyCheckpoints) {
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
            .sheet(isPresented: $showConversationPracticePasteImporter) {
                ConversationPracticePasteImportSheet { pack in
                    importPastedConversationPracticePack(pack)
                }
                .presentationDetents([.medium, .large])
            }
            .fileImporter(
                isPresented: $showConversationPracticeImporter,
                allowedContentTypes: [RadixFileTypes.json],
                allowsMultipleSelection: false
            ) { result in
                importConversationPracticePack(result)
            }
            .fileExporter(
                isPresented: $showSentenceDatabaseExporter,
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
                isPresented: $showSentenceDatabaseImporter,
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
                pendingDeletion: $pendingSentenceExampleDeletion,
                onDelete: { record in
                    deleteSentenceExamples([record], statusMessage: "Deleted")
                }
            ))
            .alert("Delete Matching Sentences?", isPresented: $showDeleteFilteredSentenceExamplesConfirmation) {
                Button("Cancel", role: .cancel) {}
                Button(sentenceExampleBulkDeleteConfirmationTitle, role: .destructive) {
                    deleteFilteredSentenceExamples()
                }
            } message: {
                Text(sentenceExampleBulkDeleteMessage)
            }
            .alert("Delete Selected Sentences?", isPresented: $showDeleteSelectedSentenceExamplesConfirmation) {
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
            .alert("Clear Saved Sentences?", isPresented: $showClearSentenceDatabaseConfirmation) {
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
            .alert(item: $studyAIFallbackTask) { task in
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
