import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func browseSourceDisclosure(description: String) -> some View {
        let selectedCollection = store.selectedBrowseCollection

        VStack(alignment: .leading, spacing: 10) {
            browseSourceSwitcher

            if showBrowseSource {
                browseSavedPageOptions
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if let selectedCollection {
                selectedImageSourceLabel(selectedCollection)
            } else {
                HStack(spacing: 8) {
                    smartGridControls
                    Spacer(minLength: 0)
                    Text(description)
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .multilineTextAlignment(.trailing)
                }
            }
        }
        .padding(selectedCollection == nil ? 10 : 8)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(selectedCollection == nil ? RadixTheme.separator : Color.clear, lineWidth: 0.5)
        )
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var browseSourceSwitcher: some View {
        ViewThatFits(in: .horizontal) {
            HStack(spacing: 6) {
                browseSourceSwitchButtons
            }
            VStack(spacing: 6) {
                browseSourceSwitchButtons
            }
        }
    }

    private var browseSourceSwitchButtons: some View {
        Group {
            browseSourceSwitchButton(
                title: "Dictionary",
                icon: "book",
                isActive: store.selectedBrowseCollection == nil
            ) {
                store.selectBrowseCollection(id: nil)
                withAnimation(.easeInOut(duration: 0.16)) {
                    showBrowseSource = false
                }
            }

            browseSourceSwitchButton(
                title: browsePagesSwitchTitle,
                icon: "photo.on.rectangle",
                isActive: store.selectedBrowseCollection != nil || showBrowseSource
            ) {
                withAnimation(.easeInOut(duration: 0.16)) {
                    showBrowseSource.toggle()
                }
            }
        }
    }

    private var browsePagesSwitchTitle: String {
        if isPhoneBrowseLayout {
            return store.allCollections.isEmpty ? "Pages" : "Pages \(store.allCollections.count)"
        }
        return store.allCollections.isEmpty ? "Saved Pages" : "Saved Pages (\(store.allCollections.count))"
    }

    func browseSourceSwitchButton(
        title: String,
        icon: String,
        isActive: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            Label(title, systemImage: icon)
                .font(ResponsiveFont.caption.weight(.semibold))
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(maxWidth: .infinity)
                .padding(.horizontal, 10)
                .padding(.vertical, 9)
                .background(isActive ? Color.accentColor : RadixTheme.background)
                .foregroundStyle(isActive ? Color.white : Color.primary)
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
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
                    Text(collection.name.isEmpty ? "Scanned Page" : collection.name)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(1)
                    Text("\(collection.characters.count) characters")
                        .font(ResponsiveFont.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer(minLength: 0)

                Button {
                    store.selectBrowseCollection(id: nil)
                    withAnimation(.easeInOut(duration: 0.16)) {
                        showBrowseSource = false
                    }
                } label: {
                    Image(systemName: "xmark.circle")
                        .font(.system(size: 16, weight: .semibold))
                        .frame(width: 32, height: 32)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Return to Dictionary")
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
        HStack(spacing: 6) {
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
            })

            Button {
                beginTranslationReport(collection)
            } label: {
                Label(
                    collection.translationReport == nil ? "Save Translation" : "View Translation",
                    systemImage: collection.translationReport == nil ? "doc.badge.plus" : "doc.text"
                )
                .labelStyle(.titleAndIcon)
                .frame(minWidth: 130)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel(collection.translationReport == nil ? "Save Translation" : "View Translation")

            Button {
                pagePhraseListCollection = collection
            } label: {
                Image(systemName: "text.quote")
                    .frame(width: 34)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Choose Page Phrases")

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
