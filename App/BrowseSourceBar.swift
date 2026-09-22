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
            SavedPageWorkspaceHeader(
                collection: collection,
                isActive: true,
                dateMode: browsePageSortOrder
            ) {
                browsePageSelectionSwitcher(collection)
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
            browsePageActionsMenu(
                collection,
                usesCompactLabel: true,
                compactControlSize: 28
            )

            if let sourceOCRLabel = browseSourceOCRLayerLabel(for: collection),
               sourceOCRLabel != "Original OCR" {
                Text(sourceOCRLabel)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .lineLimit(1)
                    .padding(.horizontal, 8)
                    .frame(minHeight: 32)
                    .radixSurface(RadixAccent.primary.opacity(0.08))
                    .help("Browse shows captured page tiles. Study opens page learning.")
            }

            readBrowseSourceButton(collection)

            BrowseImageScriptToggle(mode: $browseImageScriptMode)
                .fixedSize(horizontal: true, vertical: false)

            browsePageWorkspaceSwitcher(collection)

            browsePageGridFilterButton
        }
    }

    func browsePageActionsMenu(
        _ collection: CharacterCollection,
        usesCompactLabel: Bool = false,
        compactControlSize: CGFloat? = nil
    ) -> some View {
        CollectionPageActionsMenu(
                collection: collection,
                actionHandlers: CollectionPageActionHandlers(
                    rename: { beginRenaming(collection) },
                    edit: { beginEditing(collection) },
                    choosePhrases: { pagePhraseListCollection = collection },
                    originalOCR: collection.sourceType == .ocr ? {
                        openOriginalOCRPage(for: collection)
                    } : nil,
                    translation: { beginTranslationReport(collection) },
                    delete: { pendingBrowseDeleteCollection = collection }
                ),
                hasAutomaticAIConfiguration: store.hasAutomaticAIConfiguration,
                aiTasks: browsePageAITasks(for: collection),
                usesCompactLabel: usesCompactLabel,
                compactControlSize: compactControlSize
            )
    }

    var browsePageGridFilterButton: some View {
        let showsUniqueItems = browsePageGridFilter == .unique
        return Button {
            browsePageGridFilter = showsUniqueItems ? .all : .unique
        } label: {
            Text(showsUniqueItems ? "Unique" : "All")
            .font(ResponsiveFont.caption.weight(.semibold))
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 6)
            .foregroundStyle(showsUniqueItems ? Color.white : Color.primary)
            .radixSurface(showsUniqueItems ? RadixAccent.primary : RadixTheme.secondaryBackground)
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Browse page grid filter")
        .accessibilityValue(showsUniqueItems ? "Unique phrases and unique non-phrase characters" : "All page content")
        .help(showsUniqueItems ? "Show all page content" : "Show each phrase and non-phrase character once")
    }

    func browseSourceOCRLayerLabel(for collection: CharacterCollection) -> String? {
        guard collection.sourceType == .ocr else { return nil }
        return collection.correctedFromCollectionID == nil ? "Original OCR" : "Corrected OCR"
    }

    func openOriginalOCRPage(for collection: CharacterCollection) {
        let originalID = collection.correctedFromCollectionID ?? collection.id
        store.selectBrowseCollection(id: originalID)
        store.shouldCloseBrowseSource = true
    }

    func browsePageWorkspaceSwitcher(_ collection: CharacterCollection) -> some View {
        PageWorkspaceSwitcher(selectedMode: .browse) { mode in
            if mode == .study {
                store.goToPagesWorkspace(id: collection.id)
            }
        }
        .help("Switch between browsing and studying this page")
    }

    func browsePageSelectionSwitcher(_ collection: CharacterCollection) -> some View {
        PageSelectionSwitcher(
            pages: store.sortedCollections(order: browsePageSortOrder),
            selectedPageID: store.selectedBrowseCollectionID,
            displayName: { store.collectionDisplayName($0.name) },
            onSelect: { page in
                store.goToBrowseCollection(id: page.id, preservingOrigin: true)
            },
            sortOrder: Binding(
                get: { browsePageSortOrder },
                set: { browsePageSortOrder = $0 }
            ),
            labelTitle: store.collectionDisplayName(collection.name),
            labelFont: ResponsiveFont.subheadline.weight(.semibold),
            labelForegroundStyle: RadixAccent.primary,
            labelMinWidth: nil
        )
        .help("Switch saved page")
    }

    func readBrowseSourceButton(_ collection: CharacterCollection) -> some View {
        Button {
            _ = store.speakCharacters(in: browseImageDisplayText(collection.characters.joined()))
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(.system(size: 14, weight: .semibold))
                .frame(width: 28, height: 28)
                .contentShape(Rectangle())
        }
        .buttonStyle(.bordered)
        .controlSize(.mini)
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
