import SwiftUI
import ImageIO
import UniformTypeIdentifiers

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
    var showAddToMemoryButton: Bool = true
    var isVertical: Bool = false
    var onClear: (() -> Void)? = nil
    @State private var showPhraseTableSheet = false
    @State private var variantIndex: Int = 0

    private var usesShortActionLabels: Bool {
        #if targetEnvironment(macCatalyst)
        return isVertical
        #else
        return isVertical || UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            let isInMemory = store.rootBreadcrumb.contains(character)

            if !isVertical {
                previewActionArea(isInMemory: isInMemory)
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
                                    (
                                        Text(store.isTraditional(char) ? "Traditional" : "Simplified")
                                            .font(.system(size: 12, weight: .regular))
                                        +
                                        Text(store.isTraditional(char) ? "繁" : "简")
                                            .font(.system(size: 14, weight: .regular))
                                    )
                                        .foregroundStyle(.secondary)
                                        .lineLimit(1)
                                        .minimumScaleFactor(0.85)
                                        .padding(.vertical, 6)
                                    
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

                    if isVertical {
                        previewActionArea(isInMemory: isInMemory)
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
        Button {
            store.refreshPhrases(for: character)
            showPhraseTableSheet = true
        } label: {
            previewActionLabel(usesShortActionLabels ? "Phrase" : "Phrases", systemImage: "text.quote")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(previewActionFont)
    }

    private var rootsTrigger: some View {
        Button {
            store.goToRoots(character: character)
        } label: {
            previewActionLabel(usesShortActionLabels ? "Root" : "Roots", systemImage: "tree")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(previewActionFont)
    }

    private var editCharacterTrigger: some View {
        Button {
            store.openQuickCharacterEditor(character)
        } label: {
            previewActionLabel(usesShortActionLabels ? "Note" : "Notes", systemImage: "note.text")
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(previewActionFont)
    }

    private var speechOptionsMenu: some View {
        Button {
            store.speakCharacter(character)
        } label: {
            if isVertical {
                Image(systemName: "speaker.wave.2")
                    .frame(minWidth: 24, minHeight: 28)
            } else {
                Image(systemName: "speaker.wave.2")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .font(previewActionFont)
        .help("Speak this character")
        .contextMenu {
            Toggle("Speak on selection", isOn: $store.speechEnabled)
        }
    }

    @ViewBuilder
    private func previewActionArea(isInMemory: Bool) -> some View {
        if isVertical {
            VStack(alignment: .leading, spacing: 8) {
                if let statusLabel {
                    Text(statusLabel)
                        .font(statusLabelFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }

                HStack(spacing: 4) {
                    if showAddToMemoryButton {
                        memoryButton(isInMemory: isInMemory)
                    }
                    editCharacterTrigger
                    phraseTableTrigger
                    rootsTrigger
                    speechOptionsMenu
                    if showClearButton, store.previewCharacter != nil, store.previewCharacter != character {
                        clearPreviewButton
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
            }
        } else {
            HStack(spacing: statusLabel == nil ? 12 : 10) {
                if let statusLabel {
                    Text(statusLabel)
                        .font(statusLabelFont)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                }
                Spacer(minLength: statusLabel == nil ? 12 : 8)
                if showAddToMemoryButton {
                    memoryButton(isInMemory: isInMemory)
                }
                editCharacterTrigger
                phraseTableTrigger
                rootsTrigger
                speechOptionsMenu
                if showClearButton, store.previewCharacter != nil, store.previewCharacter != character {
                    clearPreviewButton
                }
            }
            .padding(.vertical, statusLabel == nil ? 2 : 0)
        }
    }

    @ViewBuilder
    private func memoryButton(isInMemory: Bool) -> some View {
        let button = Button {
            store.toggleRootBreadcrumb(character)
        } label: {
            previewActionLabel(usesShortActionLabels ? "Mem" : "Memory", systemImage: isInMemory ? "bookmark.fill" : "bookmark")
        }

        if isInMemory {
            button
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
                .font(previewActionFont)
                .help("Remove this character from Memory.")
                .accessibilityHint("Removes this character from Memory.")
        } else {
            button
                .buttonStyle(.bordered)
                .controlSize(.small)
                .font(previewActionFont)
                .help("Add this character to Memory.")
                .accessibilityHint("Adds this character to Memory.")
        }
    }

    private var clearPreviewButton: some View {
        Button {
            onClear?()
        } label: {
            if isVertical {
                previewActionLabel("Clear", systemImage: "xmark")
            } else {
                Text("Clear Preview")
            }
        }
        .font(ResponsiveFont.caption)
    }

    @ViewBuilder
    private func previewActionLabel(_ title: String, systemImage: String) -> some View {
        if isVertical {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minHeight: 28)
        } else {
            Text(title)
        }
    }

    private var statusLabelFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.caption
        #else
        return ResponsiveFont.headline
        #endif
    }

    private var previewActionFont: Font {
        (isVertical ? ResponsiveFont.caption2 : ResponsiveFont.caption).weight(.semibold)
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

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                }
            }
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
        Button(store.characterNotesActionTitle(for: character)) {
            store.openQuickCharacterEditor(character)
        }
        Divider()
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
        Menu("Stroke Animation") {
            Button("Share Animation") {
                shareAnimation(for: character)
            }
            Button("Open in Browser") {
                openAnimationInBrowser(for: character)
            }
            Button("Copy Player Link") {
                copyAnimationPlayerLink(for: character)
            }
        }
        Divider()
        Button("Open in Roots") {
            store.goToRoots(character: character)
        }
        Button("Open in AI Link") {
            store.goToAILink(character: character)
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

private func shareAnimation(for character: String) {
    let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isSingleChineseCharacter else {
        return
    }

    Task {
        do {
            let gifURL = try await HanziWriterGIFExporter.export(character: trimmed)
            await presentShareSheet(items: [gifURL])
        } catch {
            debugPrint("Could not create animation for \(trimmed): \(error)")
        }
    }
}

@MainActor
private func openAnimationInBrowser(for character: String) {
    guard let url = hostedHanziWriterAnimationURL(for: character) else {
        return
    }

    #if canImport(UIKit)
    UIApplication.shared.open(url)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
}

private func copyAnimationPlayerLink(for character: String) {
    guard let url = hostedHanziWriterAnimationURL(for: character) else {
        return
    }
    copyToClipboard(url.absoluteString)
}

private func hostedHanziWriterAnimationURL(for character: String) -> URL? {
    let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isSingleChineseCharacter else {
        return nil
    }

    var components = URLComponents(string: "https://dkwang62.github.io/Radix/animate.html")
    components?.queryItems = [
        URLQueryItem(name: "char", value: trimmed)
    ]
    return components?.url
}

@MainActor
private func presentShareSheet(items: [Any]) {
    #if canImport(UIKit)
    guard let presenter = UIApplication.shared.radixTopMostViewController else { return }
    let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = presenter.view
    controller.popoverPresentationController?.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
    )
    presenter.present(controller, animated: true)
    #elseif canImport(AppKit)
    guard let window = NSApplication.shared.keyWindow,
          let view = window.contentView else { return }
    let picker = NSSharingServicePicker(items: items)
    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    #endif
}

private enum HanziWriterGIFExporter {
    private static let canvasSize = 360
    private static let padding: CGFloat = 28
    private static let strokeFrameDelay = 0.16
    private static let holdFrameDelay = 0.8

    static func export(character: String) async throws -> URL {
        let data = try await fetchStrokeData(for: character)
        let frames = renderFrames(from: data)
        let safeName = character.unicodeScalars.map { String(format: "%04X", $0.value) }.joined(separator: "-")
        let outputURL = FileManager.default.temporaryDirectory
            .appendingPathComponent("Radix-\(safeName)-stroke-order.gif")

        try writeGIF(frames: frames, to: outputURL)
        return outputURL
    }

    private static func fetchStrokeData(for character: String) async throws -> HanziWriterStrokeData {
        guard let encodedCharacter = character.addingPercentEncoding(withAllowedCharacters: .urlPathAllowed),
              let url = URL(string: "https://cdn.jsdelivr.net/npm/hanzi-writer-data@latest/\(encodedCharacter).json") else {
            throw URLError(.badURL)
        }

        let (data, response) = try await URLSession.shared.data(from: url)
        if let httpResponse = response as? HTTPURLResponse,
           !(200...299).contains(httpResponse.statusCode) {
            throw URLError(.badServerResponse)
        }

        return try JSONDecoder().decode(HanziWriterStrokeData.self, from: data)
    }

    private static func renderFrames(from data: HanziWriterStrokeData) -> [GIFFrame] {
        let paths = data.strokes.compactMap { HanziSVGPathParser.parse($0) }
        guard !paths.isEmpty else { return [] }

        var frames: [GIFFrame] = [
            GIFFrame(image: render(paths: paths, completedCount: 0), delay: strokeFrameDelay)
        ]

        for index in paths.indices {
            frames.append(GIFFrame(image: render(paths: paths, completedCount: index, activeIndex: index, activeAlpha: 0.5), delay: strokeFrameDelay))
            frames.append(GIFFrame(image: render(paths: paths, completedCount: index + 1), delay: strokeFrameDelay))
        }

        frames.append(GIFFrame(image: render(paths: paths, completedCount: paths.count), delay: holdFrameDelay))
        return frames
    }

    private static func render(paths: [CGPath], completedCount: Int, activeIndex: Int? = nil, activeAlpha: CGFloat = 1) -> CGImage {
        let format = UIGraphicsImageRendererFormat.default()
        format.scale = 2
        let renderer = UIGraphicsImageRenderer(size: CGSize(width: canvasSize, height: canvasSize), format: format)

        let image = renderer.image { context in
            let cgContext = context.cgContext
            UIColor.white.setFill()
            cgContext.fill(CGRect(x: 0, y: 0, width: canvasSize, height: canvasSize))

            var transform = hanziTransform(size: CGFloat(canvasSize), padding: padding)

            UIColor(white: 0.88, alpha: 1).setFill()
            for path in paths {
                cgContext.addPath(path.copy(using: &transform) ?? path)
                cgContext.fillPath()
            }

            UIColor(white: 0.18, alpha: 1).setFill()
            for path in paths.prefix(completedCount) {
                cgContext.addPath(path.copy(using: &transform) ?? path)
                cgContext.fillPath()
            }

            if let activeIndex, paths.indices.contains(activeIndex) {
                UIColor(white: 0.18, alpha: activeAlpha).setFill()
                cgContext.addPath(paths[activeIndex].copy(using: &transform) ?? paths[activeIndex])
                cgContext.fillPath()
            }
        }

        return image.cgImage!
    }

    private static func hanziTransform(size: CGFloat, padding: CGFloat) -> CGAffineTransform {
        let minX: CGFloat = 0
        let minY: CGFloat = -124
        let hanziWidth: CGFloat = 1024
        let drawableSize = size - (padding * 2)
        let scale = drawableSize / hanziWidth
        let xOffset = padding - (minX * scale)
        let yOffset = padding - (minY * scale)

        return CGAffineTransform(a: scale, b: 0, c: 0, d: -scale, tx: xOffset, ty: size - yOffset)
    }

    private static func writeGIF(frames: [GIFFrame], to url: URL) throws {
        guard !frames.isEmpty else {
            throw CocoaError(.fileWriteUnknown)
        }

        if FileManager.default.fileExists(atPath: url.path) {
            try FileManager.default.removeItem(at: url)
        }

        guard let destination = CGImageDestinationCreateWithURL(
            url as CFURL,
            UTType.gif.identifier as CFString,
            frames.count,
            nil
        ) else {
            throw CocoaError(.fileWriteUnknown)
        }

        let gifProperties = [
            kCGImagePropertyGIFDictionary: [
                kCGImagePropertyGIFLoopCount: 0
            ]
        ] as CFDictionary
        CGImageDestinationSetProperties(destination, gifProperties)

        for frame in frames {
            let frameProperties = [
                kCGImagePropertyGIFDictionary: [
                    kCGImagePropertyGIFDelayTime: frame.delay
                ]
            ] as CFDictionary
            CGImageDestinationAddImage(destination, frame.image, frameProperties)
        }

        guard CGImageDestinationFinalize(destination) else {
            throw CocoaError(.fileWriteUnknown)
        }
    }
}

private struct HanziWriterStrokeData: Decodable {
    let strokes: [String]
}

private struct GIFFrame {
    let image: CGImage
    let delay: Double
}

private enum HanziSVGPathParser {
    static func parse(_ path: String) -> CGPath? {
        let tokens = tokenize(path)
        guard !tokens.isEmpty else { return nil }

        let mutablePath = CGMutablePath()
        var index = 0
        var command: String?
        var current = CGPoint.zero
        var firstPoint = CGPoint.zero

        while index < tokens.count {
            if tokens[index].isSVGCommand {
                command = tokens[index]
                index += 1
            }

            guard let activeCommand = command else { break }

            switch activeCommand {
            case "M", "m":
                guard let point = readPoint(tokens, &index, relativeTo: activeCommand == "m" ? current : nil) else { return mutablePath }
                mutablePath.move(to: point)
                current = point
                firstPoint = point
                if activeCommand == "M" { command = "L" } else { command = "l" }
            case "L", "l":
                guard let point = readPoint(tokens, &index, relativeTo: activeCommand == "l" ? current : nil) else { return mutablePath }
                mutablePath.addLine(to: point)
                current = point
            case "Q", "q":
                guard let control = readPoint(tokens, &index, relativeTo: activeCommand == "q" ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: activeCommand == "q" ? current : nil) else { return mutablePath }
                mutablePath.addQuadCurve(to: end, control: control)
                current = end
            case "C", "c":
                guard let control1 = readPoint(tokens, &index, relativeTo: activeCommand == "c" ? current : nil),
                      let control2 = readPoint(tokens, &index, relativeTo: activeCommand == "c" ? current : nil),
                      let end = readPoint(tokens, &index, relativeTo: activeCommand == "c" ? current : nil) else { return mutablePath }
                mutablePath.addCurve(to: end, control1: control1, control2: control2)
                current = end
            case "Z", "z":
                mutablePath.closeSubpath()
                current = firstPoint
            default:
                return mutablePath
            }
        }

        return mutablePath
    }

    private static func tokenize(_ path: String) -> [String] {
        let pattern = "[A-Za-z]|[-+]?(?:\\d*\\.\\d+|\\d+)(?:[eE][-+]?\\d+)?"
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(path.startIndex..<path.endIndex, in: path)
        return regex.matches(in: path, range: range).compactMap { match in
            guard let tokenRange = Range(match.range, in: path) else { return nil }
            return String(path[tokenRange])
        }
    }

    private static func readPoint(_ tokens: [String], _ index: inout Int, relativeTo origin: CGPoint?) -> CGPoint? {
        guard index + 1 < tokens.count,
              let x = Double(tokens[index]),
              let y = Double(tokens[index + 1]) else {
            return nil
        }
        index += 2

        if let origin {
            return CGPoint(x: origin.x + x, y: origin.y + y)
        }
        return CGPoint(x: x, y: y)
    }
}

private extension String {
    var isSVGCommand: Bool {
        count == 1 && range(of: "[A-Za-z]", options: .regularExpression) != nil
    }
}

#if canImport(UIKit)
private extension UIApplication {
    var radixTopMostViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .radixTopMostPresentedViewController
    }
}

private extension UIViewController {
    var radixTopMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.radixTopMostPresentedViewController
        }
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.radixTopMostPresentedViewController ?? navigationController
        }
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.radixTopMostPresentedViewController ?? tabBarController
        }
        return self
    }
}
#endif

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
                Button(store.phraseNotesActionTitle(for: trimmedWord)) {
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
        return (0x3400...0x4DBF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0x20000...0x2EBEF).contains(scalar.value)
    }
}
