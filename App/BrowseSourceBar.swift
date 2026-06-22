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
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func selectedImageSourceLabel(_ collection: CharacterCollection) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 10) {
                Image(systemName: "photo.on.rectangle")
                    .font(.system(size: 17, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 34, height: 34)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text(collection.name.isEmpty ? "Saved Page" : collection.name)
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
        .padding(10)
        .background(RadixTheme.background)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    func dictionarySourceLabel(description: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: "book")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                        .background(RadixTheme.secondaryBackground)
                        .clipShape(RoundedRectangle(cornerRadius: 8))

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

    func browseSourceLabel(collection: CharacterCollection?) -> some View {
        HStack(spacing: 8) {
            if collection == nil {
                smartGridControls
            } else {
                Spacer()
            }
            Spacer(minLength: 0)
            Text(collection == nil ? "Dictionary" : "Source")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(collection == nil ? Color.secondary : Color.primary)
                .lineLimit(1)
        }
    }

    func selectedImageSourceActions(_ collection: CharacterCollection) -> some View {
        let translationTitle = collection.translationReport == nil ? "Save Translation" : "View Translation"
        let translationIcon = collection.translationReport == nil ? "doc.badge.plus" : "doc.text"

        return HStack(spacing: 6) {
            Button {
                beginEditing(collection)
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 34)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Edit")

            CollectionAITaskMenu(collection: collection, onManualExtract: {
                beginManualPhraseExtraction(collection)
            }, onAIExtract: {
                runBrowseGeminiPhraseExtraction(collection)
            }, onTranslate: {
                beginBrowseTranslation(collection)
            }, onTranslateAndSave: {
                runBrowseGeminiTranslationAndSave(collection)
            }, isCompact: true)

            Button {
                beginTranslationReport(collection)
            } label: {
                Image(systemName: translationIcon)
                    .frame(width: 34)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(translationTitle)
            .help(translationTitle)

            Button {
                pagePhraseListCollection = collection
            } label: {
                Image(systemName: "text.quote")
                    .frame(width: 34)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Choose Page Phrases")
            .help("Choose Page Phrases")

            BrowseImageScriptToggle(mode: $browseImageScriptMode)

            readBrowseSourceButton(collection)
        }
    }

    func readBrowseSourceButton(_ collection: CharacterCollection) -> some View {
        Button {
            _ = store.speakCharacters(in: browseImageDisplayText(collection.characters.joined()))
        } label: {
            Image(systemName: "speaker.wave.2")
                .frame(width: 34)
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
