import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func browseSourceDisclosure(description: String) -> some View {
        let selectedCollection = store.selectedBrowseCollection

        VStack(alignment: .leading, spacing: 10) {
            if showBrowseSource {
                browseSavedPageOptions
            } else if let selectedCollection {
                selectedImageSourceLabel(selectedCollection)
            } else {
                dictionarySourceLabel(description: description)
            }
        }
        .padding(showBrowseSource || selectedCollection == nil ? 10 : 8)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(showBrowseSource || selectedCollection == nil ? RadixTheme.separator : Color.clear, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))
    }

    func selectedImageSourceLabel(_ collection: CharacterCollection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            ScrollView(.horizontal, showsIndicators: false) {
                selectedImageSourceActions(collection)
            }

            if let imageActionMessage {
                Text(imageActionMessage)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .radixCard(
            padding: RadixLayoutMetrics.compactCardPadding,
            background: RadixTheme.background
        )
    }

    func dictionarySourceLabel(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(RadixTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

                    Text("Dictionary")
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                }
                    .contentShape(Rectangle())
                    .onTapGesture {
                        toggleDictionaryHelp()
                    }
                    .onLongPressGesture {
                        toggleDictionaryHelp()
                    }
                    .accessibilityLabel("Dictionary help")
                    .accessibilityHint("Shows or hides dictionary help")
                    .accessibilityAddTraits(.isButton)
                    .accessibilityAction {
                        toggleDictionaryHelp()
                    }

                smartGridControls
                Spacer(minLength: 0)
                browseSourceBackButton
            }

            if showDictionaryHelp {
                Text(description)
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    func toggleDictionaryHelp() {
        withAnimation(.easeInOut(duration: 0.16)) {
            showDictionaryHelp.toggle()
        }
    }

    var browseSourceBackButton: some View {
        Button {
            withAnimation(.easeInOut(duration: 0.16)) {
                showBrowseSource = true
            }
        } label: {
            HStack(spacing: 7) {
                Image(systemName: "chevron.left")
                Image(systemName: "photo.on.rectangle")
            }
            .font(.system(size: 16, weight: .semibold))
            .frame(width: 52, height: 32)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Choose Browse Source")
        .help("Choose Browse Source")
    }

    func selectedImageSourceActions(_ collection: CharacterCollection) -> some View {
        return HStack(spacing: 6) {
            browseSourceBackButton

            Text("\(collection.characters.count) characters")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(minHeight: 32)
                .background(RadixTheme.secondaryBackground.opacity(0.55))
                .clipShape(RoundedRectangle(cornerRadius: 8))

            CollectionPageActionsMenu(
                collection: collection,
                onEdit: {
                    beginEditing(collection)
                },
                onChoosePhrases: {
                    pagePhraseListCollection = collection
                }
            )

            BrowseImageScriptToggle(mode: $browseImageScriptMode)

            readBrowseSourceButton(collection)
        }
    }

    func pageAITasks(for collection: CharacterCollection) -> [CollectionPageAITask] {
        var tasks: [CollectionPageAITask] = []

        if collection.sourceType == .ocr && collection.correctedFromCollectionID == nil {
            tasks.append(CollectionPageAITask(
                id: AIResultTaskID.checkOCR,
                title: "Check OCR",
                systemImage: "text.viewfinder",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.checkOCR) },
                automaticAction: { runAutomaticPageAIAction { runAutomaticOCRReview(collection) } }
            ))
        }

        tasks.append(contentsOf: [
            CollectionPageAITask(
                id: AIResultTaskID.extractPhrases,
                title: "Extract Phrases",
                systemImage: "text.badge.plus",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.extractPhrases) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiPhraseExtraction(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.translatePage,
                title: "Translate Page",
                systemImage: RadixGlossaryIcon.systemImage(for: RadixTerm.translation),
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.translatePage) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiTranslationAndSave(collection) } }
            ),
            CollectionPageAITask(
                id: "task8",
                title: "Create Quiz",
                systemImage: "questionmark.circle",
                manualAction: { beginAILinkPageTask(collection, taskID: "task8") },
                automaticAction: { runAutomaticPageAIAction { beginPageQuiz(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.extractSentences,
                title: "Extract Sentences",
                systemImage: "bubble.left.and.bubble.right",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.extractSentences) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiSentenceExtraction(collection) } }
            ),
            CollectionPageAITask(
                id: AIResultTaskID.createPagePractice,
                title: "Create Practice from Page",
                systemImage: "sparkles",
                manualAction: { beginAILinkPageTask(collection, taskID: AIResultTaskID.createPagePractice) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiPagePracticeGeneration(collection) } }
            )
        ])

        return tasks
    }

    private func runAutomaticPageAIAction(_ action: () -> Void) {
        guard !store.geminiAPIKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            store.goToSettingsForAPIKeySetup()
            return
        }
        action()
    }

    func readBrowseSourceButton(_ collection: CharacterCollection) -> some View {
        Button {
            _ = store.speakCharacters(in: browseImageDisplayText(collection.characters.joined()))
        } label: {
            Image(systemName: "speaker.wave.2")
                .radixMinimumTapTarget()
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .disabled(collection.characters.isEmpty)
        .accessibilityLabel("Read Aloud")
        .help("Read Aloud")
    }

    var browseGridDescription: String {
        if let collection = store.selectedBrowseCollection {
            return "\(collection.characters.count) characters"
        }

        return store.gridSortMode == .componentFrequency ?
            "Components, strokes, radicals, structure." :
            "Common characters first. Refine with filters."
    }
}
