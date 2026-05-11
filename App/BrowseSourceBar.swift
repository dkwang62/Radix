import SwiftUI

extension FilterGridTab {
    @ViewBuilder
    func browseSourceDisclosure(description: String) -> some View {
        let selectedCollection = store.selectedBrowseCollection

        VStack(alignment: .leading, spacing: 8) {
            DisclosureGroup(isExpanded: $showBrowseSource) {
                VStack(alignment: .leading, spacing: 10) {
                    browseSourceOptions

                    if isPhoneBrowseLayout, selectedCollection == nil {
                        Text(description)
                            .font(ResponsiveFont.caption2)
                            .italic()
                            .foregroundStyle(.secondary)
                            .padding(.horizontal, 4)
                    }
                }
                .padding(.top, 8)
            } label: {
                if let selectedCollection {
                    selectedImageSourceLabel(selectedCollection)
                } else {
                    browseSourceLabel(collection: nil)
                }
            }
        }
        .padding(selectedCollection == nil ? 10 : 8)
        .background(Color(.secondarySystemBackground).opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func selectedImageSourceLabel(_ collection: CharacterCollection) -> some View {
        HStack(spacing: 8) {
            selectedImageSourceActions(collection)
            Spacer(minLength: 0)
        }
    }

    func browseSourceLabel(collection: CharacterCollection?) -> some View {
        HStack(spacing: 8) {
            if collection == nil {
                smartGridControls
            } else {
                Spacer()
            }
            Spacer(minLength: 0)
            Text("Source")
                .font(ResponsiveFont.caption.weight(.semibold))
                .lineLimit(1)
        }
    }

    func selectedImageSourceActions(_ collection: CharacterCollection) -> some View {
        HStack(spacing: 8) {
            Button {
                beginEditing(collection)
            } label: {
                Image(systemName: "pencil")
                    .frame(width: 28)
            }
            .buttonStyle(.bordered)
            .controlSize(.small)
            .accessibilityLabel("Edit")

            CollectionAITaskMenu(collection: collection) { taskID in
                store.goToAILinkCollectionTask(collection: collection, taskID: taskID)
            }

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
            "Characters most often used as components first." :
            "Most common characters first."
    }
}
