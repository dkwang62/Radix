import SwiftUI
import UIKit

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

    func browseImageDisplayCharacter(_ character: String) -> String {
        browseImageDisplayText(character)
    }

    func browseImageDisplayText(_ text: String) -> String {
        useTraditionalBrowseImageScript ? store.traditionalText(text) : store.simplifiedText(text)
    }

    func beginEditing(_ collection: CharacterCollection) {
        editingCollectionName = collection.name
        editingCollectionText = collection.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = collection
    }

    func saveEditedCollection(_ collection: CharacterCollection) {
        guard let updated = store.updateCollection(
            id: collection.id,
            newName: editingCollectionName,
            sourceText: editingCollectionText
        ) else {
            collectionEditorError = "Enter a name and at least one Chinese character that exists in Radix."
            return
        }

        editingCollectionName = updated.name
        editingCollectionText = updated.characters.joined(separator: " ")
        collectionEditorError = nil
        editingCollection = nil
    }

    var browseSourceOptions: some View {
        VStack(alignment: .leading, spacing: 6) {
            sourceOptionButton(
                title: "Dictionary",
                subtitle: "Full dictionary",
                isSelected: store.selectedBrowseCollection == nil,
                systemImage: "book"
            ) {
                store.selectBrowseCollection(id: nil)
            }

            sourceActionButton(
                title: "Create from Paste",
                subtitle: "Paste Chinese text and save it as an image source",
                systemImage: "doc.on.clipboard"
            ) {
                beginManualCollection()
            }

            ForEach(store.allCollections) { collection in
                sourceCollectionRow(collection)
            }
        }
    }

    func sourceActionButton(
        title: String,
        subtitle: String,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
        } label: {
            SourceMenuRow(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                iconColor: .accentColor,
                trailingSystemImage: "plus.circle.fill"
            )
        }
        .buttonStyle(.plain)
    }

    func sourceCollectionRow(_ collection: CharacterCollection) -> some View {
        let isSelected = store.selectedBrowseCollectionID == collection.id
        return SourceCollectionRow(
            collection: collection,
            isSelected: isSelected,
            thumbnail: sourceThumbnailImage(for: collection)
        ) {
            store.selectBrowseCollection(id: collection.id)
            withAnimation {
                showBrowseSource = false
            }
        } onDelete: {
            pendingDeleteCollection = collection
        }
    }

    func sourceThumbnailImage(for collection: CharacterCollection) -> UIImage? {
        guard let data = collection.thumbnailJPEGData else { return nil }
        return UIImage(data: data)
    }

    func sourceOptionButton(
        title: String,
        subtitle: String,
        isSelected: Bool,
        systemImage: String,
        action: @escaping () -> Void
    ) -> some View {
        Button {
            action()
            withAnimation {
                showBrowseSource = false
            }
        } label: {
            SourceMenuRow(
                title: title,
                subtitle: subtitle,
                systemImage: systemImage,
                isSelected: isSelected,
                iconColor: isSelected ? .accentColor : .secondary,
                trailingSystemImage: isSelected ? "checkmark.circle.fill" : nil
            )
        }
        .buttonStyle(.plain)
    }
}
