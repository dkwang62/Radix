import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

struct CharacterPreviewHeader: View {
    @EnvironmentObject private var store: RadixStore
    let character: String
    let showClearButton: Bool
    var statusLabel: String? = nil
    var isVertical: Bool = false
    var onClear: (() -> Void)? = nil
    @State private var showPhraseTableSheet = false
    @State private var variantIndex: Int = 0

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isSelected = store.selectedCharacter == character

            HStack(spacing: 8) {
                if let statusLabel {
                    Text(isSelected ? "Selected" : statusLabel)
                        .font(ResponsiveFont.headline)
                        .lineLimit(1)
                }
                Spacer()
                if !isSelected {
                    Button("Select") {
                        store.select(character: character)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.small)
                }
                phraseTableTrigger
                speechOptionsMenu
                if showClearButton, store.previewCharacter != nil, store.previewCharacter != character {
                    Button("Clear Preview") {
                        onClear?()
                    }
                    .font(ResponsiveFont.caption)
                }
            }

            if let item = store.item(for: character) {
                let allVariants = store.allVariants(for: item.character)
                let counterpart = allVariants.first

                // The currently selected variant (driven by card's cycle button)
                let safeIndex = allVariants.isEmpty ? 0 : variantIndex % allVariants.count
                let activeVariant = allVariants.indices.contains(safeIndex) ? allVariants[safeIndex] : counterpart

                // Determine layout container
                let container = AnyLayout(isVertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 0)))
                
                container {
                    if let activeVariant = activeVariant {
                        // Show current char alongside the currently selected variant
                        let chars = store.isTraditional(item.character)
                            ? [activeVariant.character, item.character]
                            : [item.character, activeVariant.character]
                        
                        let animContainer = AnyLayout(isVertical ? AnyLayout(HStackLayout(spacing: 0)) : AnyLayout(VStackLayout(spacing: 0)))
                        
                        animContainer {
                            ForEach(chars, id: \.self) { char in
                                VStack(spacing: 0) {
                                    Text(store.isTraditional(char) ? "TRADITIONAL" : "SIMPLIFIED")
                                        .font(.system(size: 7, weight: .black))
                                        .foregroundStyle(.secondary)
                                        .padding(.vertical, 4)
                                    
                                    StrokeOrderWebView(
                                        character: char,
                                        reloadToken: UUID(),
                                        canvasSize: isVertical ? 120 : 90
                                    )
                                    .frame(maxWidth: .infinity)
                                    .frame(height: isVertical ? 120 : 100)
                                }
                                .background(Color.secondary.opacity(0.05))
                                .border(Color(.separator).opacity(0.2), width: 0.5)
                            }
                        }
                        .frame(width: isVertical ? nil : 100)
                        .frame(maxWidth: isVertical ? .infinity : 100)
                    } else {
                        // Single animation — no variants
                        VStack(spacing: 0) {
                            Text("STROKE ORDER")
                                .font(.system(size: 7, weight: .black))
                                .foregroundStyle(.secondary)
                                .padding(.vertical, 4)
                            
                            StrokeOrderWebView(
                                character: item.character,
                                reloadToken: UUID(),
                                canvasSize: 120
                            )
                            .frame(height: 130)
                            .frame(maxWidth: .infinity)
                        }
                        .background(Color.secondary.opacity(0.05))
                        .border(Color(.separator).opacity(0.2), width: 0.5)
                        .frame(width: isVertical ? nil : 130)
                        .frame(maxWidth: isVertical ? .infinity : 130)
                    }

                    CharacterInfoCard(
                        item: item,
                        variants: allVariants.map(\.character),
                        variantIndex: $variantIndex,
                        onSelectVariant: { ch in
                            #if targetEnvironment(macCatalyst)
                            store.select(character: ch)
                            store.preview(character: ch)
                            #else
                            if UIDevice.current.userInterfaceIdiom == .phone &&
                                store.route == .search &&
                                store.homeTab == .filter {
                                store.browsePreview(character: ch)
                            } else {
                                store.select(character: ch)
                                store.preview(character: ch)
                            }
                            #endif
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $showPhraseTableSheet) {
            PhraseTableSheet(character: character, isVertical: isVertical)
                .environmentObject(store)
        }
        .onChange(of: character) { _, _ in
            variantIndex = 0
        }
    }

    private var phraseTableTrigger: some View {
        Button("Phrases") {
            store.refreshPhrases(for: character)
            showPhraseTableSheet = true
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
    }

    private var speechOptionsMenu: some View {
        Menu {
            Toggle("Speech", isOn: $store.speechEnabled)
        } label: {
            Image(systemName: store.speechMenuSymbolName)
        }
        .menuStyle(.borderlessButton)
        .controlSize(.small)
    }
}

private struct PhraseTableSheet: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let character: String
    let isVertical: Bool
    private let visiblePhraseRows = 6

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #else
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #endif
    }

    @ViewBuilder
    private var copyHintLabel: some View {
        HStack(spacing: 4) {
            Text(isRunningOnMac ? "Right-click" : "Long-press")
            Image(systemName: "doc.on.doc")
        }
        .font(ResponsiveFont.caption)
        .foregroundStyle(.secondary)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            copyHintLabel

            Picker("Length", selection: $store.phraseLength) {
                Text("2-char").tag(2)
                Text("3-char").tag(3)
                Text("4-char").tag(4)
            }
            .font(ResponsiveFont.subheadline)
            .pickerStyle(.segmented)

            if store.phrases.isEmpty {
                ContentUnavailableView(
                    "No phrases found",
                    systemImage: "text.justify",
                    description: Text("No \(store.phraseLength)-character phrases were found for \(character).")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView {
                    LazyVStack(spacing: 0) {
                        ForEach(store.phrases, id: \.id) { phrase in
                            phraseRow(phrase)
                            Divider()
                        }
                    }
                }
                .frame(height: phraseViewportHeight)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 10))

                Spacer(minLength: 0)
            }

            HStack {
                Spacer()
                DismissButton()
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .modifier(PhraseTableDetentModifier(isPhone: isPhone))
        .onAppear {
            store.refreshPhrases(for: character)
        }
        .onChange(of: store.phraseLength) { _, _ in
            store.refreshPhrases(for: character)
        }
    }

    private func phraseRow(_ phrase: PhraseItem) -> some View {
        let leadingColumnWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 150
            #else
            return isPhone ? 96 : 120
            #endif
        }()

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
            .frame(width: leadingColumnWidth, alignment: .leading)

            Text(phrase.meanings)
                .font(ResponsiveFont.body)
                .fixedSize(horizontal: false, vertical: true)
                .frame(maxWidth: .infinity, alignment: .leading)
                .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: phraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .phraseContextMenu(phrase)
    }

    private var phraseRowHeight: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return isPhone ? 72 : 82
        #endif
    }

    private var phraseViewportHeight: CGFloat {
        (phraseRowHeight * CGFloat(visiblePhraseRows)) + 5
    }
}

private struct DismissButton: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        Button("Done") {
            dismiss()
        }
        .buttonStyle(.borderedProminent)
    }
}

private struct PhraseTableDetentModifier: ViewModifier {
    let isPhone: Bool

    func body(content: Content) -> some View {
        if isPhone {
            content.presentationDetents([.medium, .large])
        } else {
            content
        }
    }
}

private struct CopyCharacterContextMenuModifier: ViewModifier {
    @EnvironmentObject private var store: RadixStore
    let character: String
    let pinyin: String?

    func body(content: Content) -> some View {
        if character.isSingleChineseCharacter {
            content.contextMenu {
                CharacterActionMenuContent(character: character, pinyin: pinyin)
            }
        } else {
            content
        }
    }
}

private struct CharacterActionMenuContent: View {
    @EnvironmentObject private var store: RadixStore
    let character: String
    let pinyin: String?
    var compact: Bool = false

    private var trimmedPinyin: String? {
        let trimmed = pinyin?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
        return trimmed.isEmpty ? nil : trimmed
    }

    private var trimmedMeaning: String? {
        store.meaningText(for: character)
    }

    private var trimmedStructure: String? {
        store.structureText(for: character)
    }

    var body: some View {
        characterActions
    }

    @ViewBuilder
    private var characterActions: some View {
        Button("Copy Character") {
            copyToClipboard(character)
        }
        if let trimmedPinyin {
            Button("Copy Pinyin") {
                copyToClipboard(trimmedPinyin)
            }
        }
        if compact {
            Menu("More") {
                extendedActions
            }
        } else {
            extendedActions
        }
    }

    @ViewBuilder
    private var extendedActions: some View {
        if let trimmedStructure {
            Button("Copy Structure") {
                copyToClipboard(trimmedStructure)
            }
        }
        if let trimmedMeaning {
            Button("Copy Meaning") {
                copyToClipboard(trimmedMeaning)
            }
        }
        Divider()
        Button("Open in Roots") {
            store.goToRoots(character: character)
        }
        Button("Open in AI Link") {
            store.goToAILink(character: character)
        }
        Button("Edit Character") {
            store.openQuickCharacterEditor(character)
        }
        Button("Add New Character") {
            store.openNewCharacterEditor()
        }
        if store.addedDictionaryCharacters.contains(character) {
            Button("Delete Character", role: .destructive) {
                store.loadDataEditEntry(for: character)
                try? store.deleteCurrentDataEditEntry()
            }
        } else if store.editedDictionaryCharactersSet.contains(character) {
            Button("Revert Character") {
                store.restoreDictionaryCharacterFromLibrary(character)
            }
        }
        Divider()
        Button(store.isFavorite(character) ? "Remove from Favorites" : "Add to Favorites") {
            store.setFavorite(character: character, isFavorite: !store.isFavorite(character))
        }
    }
}

private func copyToClipboard(_ value: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = value
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
}

extension View {
    func copyCharacterContextMenu(_ character: String, pinyin: String? = nil) -> some View {
        modifier(CopyCharacterContextMenuModifier(character: character, pinyin: pinyin))
    }

    func copyTextContextMenu(_ text: String, buttonTitle: String, secondaryText: String? = nil, secondaryButtonTitle: String? = nil) -> some View {
        modifier(CopyTextContextMenuModifier(text: text, buttonTitle: buttonTitle, secondaryText: secondaryText, secondaryButtonTitle: secondaryButtonTitle))
    }

    func phraseContextMenu(_ phrase: PhraseItem) -> some View {
        modifier(PhraseContextMenuModifier(phrase: phrase))
    }
}

private struct CopyTextContextMenuModifier: ViewModifier {
    let text: String
    let buttonTitle: String
    let secondaryText: String?
    let secondaryButtonTitle: String?

    func body(content: Content) -> some View {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmed.isEmpty {
            content
        } else {
            content.contextMenu {
                Button(buttonTitle) {
                    copyToClipboard(trimmed)
                }
                if let secondaryButtonTitle,
                   let trimmedSecondaryText = secondaryText?.trimmingCharacters(in: .whitespacesAndNewlines),
                   !trimmedSecondaryText.isEmpty {
                    Button(secondaryButtonTitle) {
                        copyToClipboard(trimmedSecondaryText)
                    }
                }
            }
        }
    }

    private func copyToClipboard(_ value: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = value
        #elseif canImport(AppKit)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(value, forType: .string)
        #endif
    }
}

private struct PhraseContextMenuModifier: ViewModifier {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.dismiss) private var dismiss
    let phrase: PhraseItem

    func body(content: Content) -> some View {
        let trimmedWord = phrase.word.trimmingCharacters(in: .whitespacesAndNewlines)
        if trimmedWord.isEmpty {
            content
        } else {
            content.contextMenu {
                Button("Copy Phrase") {
                    copyToClipboard(trimmedWord)
                }
                let trimmedPinyin = phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedPinyin.isEmpty {
                    Button("Copy Pinyin") {
                        copyToClipboard(trimmedPinyin)
                    }
                }
                let trimmedMeaning = phrase.meanings.trimmingCharacters(in: .whitespacesAndNewlines)
                if !trimmedMeaning.isEmpty {
                    Button("Copy Meaning") {
                        copyToClipboard(trimmedMeaning)
                    }
                }
                Divider()
                Button("Edit Phrase") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        store.openQuickPhraseEditor(word: trimmedWord)
                    }
                }
                Button("Add New Phrase") {
                    dismiss()
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.35) {
                        store.openNewPhraseEditor()
                    }
                }
                if store.isPhraseInAdd(trimmedWord) {
                    let isBuiltIn = store.isPhraseInBase(trimmedWord)
                    Button(isBuiltIn ? "Revert Phrase" : "Delete Phrase", role: isBuiltIn ? nil : .destructive) {
                        store.removeDataEditPhrase(word: trimmedWord)
                    }
                }
                Divider()
                Button(store.isPhraseFavorite(trimmedWord) ? "Remove from Favorites" : "Add to Favorites") {
                    store.togglePhraseFavorite(trimmedWord)
                }
            }
        }
    }
}

private extension String {
    var isSingleChineseCharacter: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else { return false }
        return (0x4E00...0x9FFF).contains(scalar.value) || (0x3400...0x4DBF).contains(scalar.value)
    }
}
