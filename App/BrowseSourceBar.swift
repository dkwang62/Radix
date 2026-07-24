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
        .radixSurface(
            RadixTheme.secondaryBackground.opacity(0.55),
            border: showBrowseSource || selectedCollection == nil ? RadixTheme.separator : Color.clear,
            borderWidth: 0.5
        )
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
            dictionaryHelpButton

            smartGridControls

            if showDictionaryHelp {
                Text(description)
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    var dictionaryHelpButton: some View {
        Button {
            toggleDictionaryHelp()
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "book")
                    .font(.system(size: 16, weight: .semibold))
                    .radixIconButtonSurface(
                        size: 32,
                        background: RadixTheme.secondaryBackground
                    )

                RadixCompactChevronLabel(
                    title: "Dictionary",
                    chevronSystemName: showDictionaryHelp ? "chevron.up" : "chevron.down",
                    font: ResponsiveFont.body.weight(.semibold),
                    chevronFont: ResponsiveFont.caption.weight(.bold),
                    chevronForegroundStyle: .secondary,
                    spacing: 8
                )
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Dictionary help")
        .accessibilityHint("Shows or hides dictionary help")
        .accessibilityValue(showDictionaryHelp ? "Shown" : "Hidden")
    }

    func toggleDictionaryHelp() {
        withAnimation(.easeInOut(duration: 0.16)) {
            showDictionaryHelp.toggle()
        }
    }

    func selectedImageSourceActions(_ collection: CharacterCollection) -> some View {
        return HStack(spacing: 6) {
            Text("\(collection.characters.count) characters")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .padding(.horizontal, 8)
                .frame(minHeight: 32)
                .radixSurface(RadixTheme.secondaryBackground.opacity(0.55))

            if let sourceOCRLabel = browseSourceOCRLayerLabel(for: collection),
               sourceOCRLabel != "Original OCR" {
                Text(sourceOCRLabel)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 32)
                    .radixSurface(RadixAccent.primary.opacity(0.08))
                    .help("Browse shows the original captured page. Extracted sentences appear in Study.")
            }

            CollectionPageActionsMenu(
                collection: collection,
                onEdit: {
                    beginEditing(collection)
                },
                onChoosePhrases: {
                    pagePhraseListCollection = collection
                },
                onViewOriginalOCR: collection.sourceType == .ocr ? {
                    openOriginalOCRPage(for: collection)
                } : nil
            )

            BrowseImageScriptToggle(mode: $browseImageScriptMode)

            readBrowseSourceButton(collection)
        }
    }

    func browseSourceOCRLayerLabel(for collection: CharacterCollection) -> String? {
        guard collection.sourceType == .ocr else { return nil }
        return collection.correctedFromCollectionID == nil ? "Original OCR" : "Corrected OCR"
    }

    func openOriginalOCRPage(for collection: CharacterCollection) {
        let originalID = collection.correctedFromCollectionID ?? collection.id
        store.selectBrowseCollection(id: originalID)
        store.shouldCloseBrowsePages = true
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
