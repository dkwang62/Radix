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
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: RadixRadius.medium))

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name.isEmpty ? RadixCopy.savedPage : collection.name)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                    Text("\(collection.characters.count) characters")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                browseSourceBackButton
            }

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
            CollectionPageActionsMenu(collection: collection, onEdit: {
                beginEditing(collection)
            }, hasGeminiAPIKey: !store.geminiAPIKey
                .trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
            onChoosePhrases: {
                pagePhraseListCollection = collection
            }, onViewTranslation: {
                beginTranslationReport(collection)
            }, aiTasks: pageAITasks(for: collection))

            BrowseImageScriptToggle(mode: $browseImageScriptMode)

            readBrowseSourceButton(collection)
        }
    }

    func pageAITasks(for collection: CharacterCollection) -> [CollectionPageAITask] {
        var tasks: [CollectionPageAITask] = []

        if collection.sourceType == .ocr && collection.correctedFromCollectionID == nil {
            tasks.append(CollectionPageAITask(
                id: "check_ocr",
                title: "Check OCR",
                systemImage: "text.viewfinder",
                manualAction: { beginOCRReview(collection) },
                automaticAction: { runAutomaticPageAIAction { runAutomaticOCRReview(collection) } }
            ))
        }

        tasks.append(contentsOf: [
            CollectionPageAITask(
                id: "extract_phrases",
                title: "Extract Phrases",
                systemImage: "text.badge.plus",
                manualAction: { beginManualPhraseExtraction(collection) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiPhraseExtraction(collection) } }
            ),
            CollectionPageAITask(
                id: "translate_page",
                title: "Translate Page",
                systemImage: "translate",
                manualAction: { beginBrowseTranslation(collection) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiTranslationAndSave(collection) } }
            ),
            CollectionPageAITask(
                id: "create_quiz",
                title: "Create Quiz",
                systemImage: "questionmark.circle",
                manualAction: { beginManualPageQuiz(collection) },
                automaticAction: { runAutomaticPageAIAction { beginPageQuiz(collection) } }
            ),
            CollectionPageAITask(
                id: "extract_sentences",
                title: "Extract Sentences",
                systemImage: "bubble.left.and.bubble.right",
                manualAction: { beginPageSentenceExtraction(collection) },
                automaticAction: { runAutomaticPageAIAction { runBrowseGeminiSentenceExtraction(collection) } }
            ),
            CollectionPageAITask(
                id: "create_page_practice",
                title: "Create Practice from Page",
                systemImage: "sparkles",
                manualAction: { beginPagePracticeGeneration(collection) },
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
