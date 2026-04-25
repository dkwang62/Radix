import SwiftUI
import PhotosUI
import UIKit

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.openURL) private var openURL
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var isProcessing = false
    @State private var statusMessage: String?
    @State private var errorMessage: String?
    @State private var gridPage = 0
    @State private var showCamera = false
    @State private var capturePreviewCharacter: String?
    @State private var captureDetailPreviewCharacter: String?
    @State private var phraseDiscoveryOutput = ""
    @State private var phraseDiscoveryCandidates: [PhraseDiscoveryCandidate] = []
    @State private var phraseDiscoveryStats = PhraseDiscoveryStats()
    @State private var phraseDiscoveryMessage: String?

    private var characters: [String] {
        CaptureTextExtractor.uniqueCharacters(in: store.activeCaptureDraft.charactersText)
    }

    private var phraseCandidates: [String] {
        CaptureTextExtractor.uniquePhrases(from: store.activeCaptureDraft.phrasesText.split(separator: "\n").map(String.init))
    }

    private var characterItems: [ComponentItem] {
        store.items(for: characters)
    }

    private var existingPhrases: [PhraseItem] {
        phraseCandidates.compactMap { store.mergedPhrase(for: $0) }
    }

    private var newPhrases: [String] {
        let existing = Set(existingPhrases.map(\.word))
        return phraseCandidates.filter { !existing.contains($0) }
    }

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    Color.clear.frame(height: 0).id("captureTop")
                    header

                    #if !targetEnvironment(macCatalyst)
                    if UIDevice.current.userInterfaceIdiom == .phone,
                       let current = captureDetailPreviewCharacter ?? capturePreviewCharacter,
                       store.item(for: current) != nil {
                        standardPhoneCharacterPreview(
                            character: current,
                            selectedCharacter: store.selectedCharacter,
                            onClear: {
                                capturePreviewCharacter = nil
                                captureDetailPreviewCharacter = nil
                                store.previewCharacter = nil
                            }
                        )
                    }
                    #endif

                    if let errorMessage {
                        Text(errorMessage)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.red)
                    }
                    if let statusMessage {
                        Text(statusMessage)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    }

                    if let selectedImage {
                        Image(uiImage: selectedImage)
                            .resizable()
                            .scaledToFit()
                            .frame(maxHeight: 260)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    if isProcessing {
                        ProgressView("Reading image...")
                            .frame(maxWidth: .infinity, alignment: .center)
                            .padding(.vertical, 24)
                    } else if store.activeCaptureDraft.rawText.isEmpty {
                        emptyState
                    } else {
                        captureResults(scrollToTop: {
                            withAnimation { proxy.scrollTo("captureTop", anchor: .top) }
                        })
                    }
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .topLeading)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            Task { await loadAndRecognize(item) }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                Task { await recognize(image) }
            }
        }
    }

    private var header: some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(alignment: .leading, spacing: 2) {
                Text("Camera")
                    .font(ResponsiveFont.title3.bold())
                Text("Image to Radix results")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
            if UIImagePickerController.isSourceTypeAvailable(.camera) {
                Button {
                    showCamera = true
                } label: {
                    Text("Camera")
                }
                .buttonStyle(.borderedProminent)
                .disabled(isProcessing)
            }
            PhotosPicker(selection: $selectedPhoto, matching: .images) {
                Text("Album")
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
    }

    private var emptyState: some View {
        ContentUnavailableView(
            "Choose an Image",
            systemImage: "camera",
            description: Text("Radix will extract Chinese text using Apple Vision, then let you review the characters and phrases in place.")
        )
        .frame(maxWidth: .infinity, minHeight: 240)
    }

    private func captureResults(scrollToTop: @escaping () -> Void) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            captureSection("Characters") {
                if characterItems.isEmpty {
                    Text("No Chinese characters found yet.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    SmartResultsGrid(
                        items: characterItems,
                        currentPage: $gridPage,
                        onPreview: { character in
                            capturePreviewCharacter = character
                            captureDetailPreviewCharacter = character
                            store.refreshPhrases(for: character)
                        },
                        onSelect: {
                            scrollToTop()
                        }
                    )
                }

                TextEditor(text: $store.activeCaptureDraft.charactersText)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 70)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            captureSection("Existing Phrases") {
                if existingPhrases.isEmpty {
                    Text("No existing Radix phrases found from this image.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    phraseTable(existingPhrases)
                }
            }

            captureSection("New Phrases") {
                if newPhrases.isEmpty {
                    Text("No new OCR-only phrase candidates.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    VStack(spacing: 0) {
                        ForEach(newPhrases, id: \.self) { phrase in
                            newPhraseRow(phrase)
                            Divider()
                        }
                    }
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }

                TextEditor(text: $store.activeCaptureDraft.phrasesText)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 86)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            phraseDiscoveryImportSection

            HStack(spacing: 10) {
                Button("Remember Characters") {
                    for character in characters {
                        store.pushRootBreadcrumb(character)
                    }
                    statusMessage = "Characters added to Remembered."
                }
                .buttonStyle(.bordered)
                .disabled(characters.isEmpty)
            }
        }
    }

    private var phraseDiscoveryImportSection: some View {
        captureSection("Phrase Discovery Import") {
            VStack(alignment: .leading, spacing: 10) {
                if !store.activeCaptureDraft.rawText.isEmpty {
                    DisclosureGroup("OCR Text Preview") {
                        Text(store.activeCaptureDraft.rawText)
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .textSelection(.enabled)
                            .frame(maxWidth: .infinity, alignment: .leading)
                            .padding(8)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                    .font(ResponsiveFont.caption.weight(.semibold))
                }

                HStack(spacing: 8) {
                    Button("Copy ChatGPT Prompt") {
                        copyPhraseDiscoveryPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(store.activeCaptureDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Clear") {
                        resetPhraseDiscovery()
                    }
                    .buttonStyle(.bordered)
                    .disabled(phraseDiscoveryOutput.isEmpty && phraseDiscoveryCandidates.isEmpty)
                }

                TextEditor(text: $phraseDiscoveryOutput)
                    .font(ResponsiveFont.body)
                    .frame(minHeight: 150)
                    .padding(6)
                    .background(Color(.secondarySystemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                HStack(spacing: 8) {
                    Button("Parse / Review") {
                        parsePhraseDiscoveryOutput()
                    }
                    .buttonStyle(.bordered)
                    .disabled(phraseDiscoveryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Select All") {
                        setAllPhraseDiscoveryCandidates(true)
                    }
                    .buttonStyle(.bordered)
                    .disabled(phraseDiscoveryCandidates.isEmpty)

                    Button("Deselect All") {
                        setAllPhraseDiscoveryCandidates(false)
                    }
                    .buttonStyle(.bordered)
                    .disabled(phraseDiscoveryCandidates.isEmpty)
                }

                phraseDiscoverySummary

                if !phraseDiscoveryCandidates.isEmpty {
                    phraseDiscoveryCandidateList
                }

                HStack {
                    Spacer()
                    Button("Import Selected") {
                        importSelectedPhraseDiscoveryCandidates()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(phraseDiscoveryCandidates.filter(\.isSelected).isEmpty)
                }

                if let phraseDiscoveryMessage {
                    Text(phraseDiscoveryMessage)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private var phraseDiscoverySummary: some View {
        let knownCount = store.phraseDiscoveryKnownPhrases(in: store.activeCaptureDraft.rawText).count
        let selectedCount = phraseDiscoveryCandidates.filter(\.isSelected).count
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            discoveryStatChip("Known in OCR", knownCount)
            discoveryStatChip("Parsed", phraseDiscoveryStats.totalParsed)
            discoveryStatChip("Duplicates", phraseDiscoveryStats.duplicatesRemoved)
            discoveryStatChip("Existing", phraseDiscoveryStats.alreadyExisting)
            discoveryStatChip("Invalid", phraseDiscoveryStats.invalidLines)
            discoveryStatChip("New", phraseDiscoveryCandidates.count)
            discoveryStatChip("Selected", selectedCount)
        }
    }

    private var phraseDiscoveryCandidateList: some View {
        VStack(spacing: 0) {
            ForEach(phraseDiscoveryCandidates) { candidate in
                phraseDiscoveryCandidateRow(candidateBinding(for: candidate))
                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func phraseDiscoveryCandidateRow(_ candidate: Binding<PhraseDiscoveryCandidate>) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Toggle(isOn: candidate.isSelected) {
                Text(candidate.wrappedValue.phrase.isEmpty ? "Phrase" : candidate.wrappedValue.phrase)
                    .font(ResponsiveFont.body.bold())
            }

            HStack(alignment: .top, spacing: 8) {
                phraseDiscoveryField("Phrase") {
                    TextField("Phrase", text: candidate.phrase)
                        .textFieldStyle(.roundedBorder)
                        .frame(width: 90)
                }
                phraseDiscoveryField("Pinyin") {
                    TextField("Pinyin", text: candidate.pinyin)
                        .textFieldStyle(.roundedBorder)
                }
            }

            phraseDiscoveryField("English Meaning") {
                TextField("Meaning", text: candidate.meaning)
                    .textFieldStyle(.roundedBorder)
            }
        }
        .padding(10)
    }

    private func candidateBinding(for candidate: PhraseDiscoveryCandidate) -> Binding<PhraseDiscoveryCandidate> {
        Binding(
            get: {
                phraseDiscoveryCandidates.first(where: { $0.id == candidate.id }) ?? candidate
            },
            set: { updatedCandidate in
                guard let index = phraseDiscoveryCandidates.firstIndex(where: { $0.id == updatedCandidate.id }) else { return }
                phraseDiscoveryCandidates[index] = updatedCandidate
            }
        )
    }

    private func discoveryStatChip(_ title: String, _ value: Int) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            Text("\(value)")
                .font(ResponsiveFont.caption.weight(.semibold))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func phraseDiscoveryField<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(title)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func phraseTable(_ phrases: [PhraseItem]) -> some View {
        VStack(spacing: 0) {
            ForEach(phrases, id: \.id) { phrase in
                phraseRow(phrase)
                Divider()
            }
        }
        .background(Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func phraseRow(_ phrase: PhraseItem) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(width: 120, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(10)
        .contentShape(Rectangle())
        .phraseContextMenu(phrase)
    }

    private func newPhraseRow(_ phrase: String) -> some View {
        HStack(spacing: 8) {
            Text(phrase)
                .font(ResponsiveFont.body.bold())
            Spacer()
            Button {
                openNewPhraseInChatGPT(phrase)
            } label: {
                Label("ChatGPT", systemImage: "arrow.up.forward.app")
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))

            Button("Notes") {
                store.openQuickPhraseEditor(word: phrase)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))
        }
        .padding(10)
    }

    private func openNewPhraseInChatGPT(_ phrase: String) {
        let prompt = """
        For "\(phrase)", return only three lines:
        line 1: Hanyu Pinyin with tone marks
        line 2: concise English meaning
        line 3: one simple Chinese example sentence using the phrase, followed by pinyin and English translation
        Do not include labels, headings, numbering, bullets, explanations, or any extra words.
        """

        #if canImport(UIKit)
        UIPasteboard.general.string = prompt
        #endif

        if let url = chatGPTURL(prompt: prompt) {
            openURL(url)
        }
    }

    private func copyPhraseDiscoveryPrompt() {
        let prompt = makePhraseDiscoveryPrompt()
        #if canImport(UIKit)
        UIPasteboard.general.string = prompt
        #endif
        if let url = chatGPTURL(prompt: prompt) {
            openURL(url)
        }
        phraseDiscoveryMessage = "Prompt copied and opened in ChatGPT. Paste ChatGPT output below when ready."
    }

    private func makePhraseDiscoveryPrompt() -> String {
        let rawText = store.activeCaptureDraft.rawText
        let knownPhrases = store.phraseDiscoveryKnownPhrases(in: rawText)
        let knownList = knownPhrases.isEmpty ? "(none)" : knownPhrases.joined(separator: "\n")

        return """
        From the Chinese text below, extract useful 2-, 3-, and 4-character Chinese phrases that are found as dictionary headwords.

        Ignore phrases already in this known list:
        \(knownList)

        Rules:
        - Keep the full text context in mind.
        - Return only useful NEW phrase candidates that are attested in Chinese dictionaries.
        - Only include a phrase if it would normally appear as an entry in a reputable dictionary such as CC-CEDICT, Pleco, MDBG, Wiktionary, or a standard Chinese dictionary.
        - Prioritize common, natural dictionary phrases.
        - Avoid rare, awkward, or accidental character combinations.
        - Avoid arbitrary n-grams, sentence fragments, partial grammar patterns, names, titles, dates, and OCR accidents unless they are also normal dictionary entries.
        - Do not invent phrases that are not clearly supported by the text.
        - If you are unsure whether a phrase is dictionary-attested, omit it.
        - Include only 2-, 3-, and 4-character Chinese phrases.
        - Provide pinyin with tone marks.
        - Provide a concise English meaning.
        - Output only in this format:
        Phrase | Pinyin | Concise English meaning

        Chinese text:
        \(rawText)

        Important:
        - Do not delete or shorten the OCR text.
        - Do not ask ChatGPT to analyze one character at a time.
        - The known phrase list is for ignoring existing phrases, not for removing context.
        """
    }

    private func parsePhraseDiscoveryOutput() {
        let parsed = PhraseDiscoveryParser.parse(phraseDiscoveryOutput)
        let existingWords = store.existingPhraseWords(in: Set(parsed.candidates.map(\.phrase)))
        phraseDiscoveryCandidates = parsed.candidates
            .filter { !existingWords.contains($0.phrase) }
            .map { candidate in
                var candidate = candidate
                candidate.isSelected = true
                return candidate
            }
        phraseDiscoveryStats = PhraseDiscoveryStats(
            totalParsed: parsed.totalParsed,
            duplicatesRemoved: parsed.duplicatesRemoved,
            alreadyExisting: existingWords.count,
            invalidLines: parsed.invalidLines
        )
        phraseDiscoveryMessage = phraseDiscoveryCandidates.isEmpty
            ? "No new phrases found after filtering existing Radix phrases."
            : "Review and edit the new phrase candidates before importing."
    }

    private func setAllPhraseDiscoveryCandidates(_ isSelected: Bool) {
        phraseDiscoveryCandidates = phraseDiscoveryCandidates.map { candidate in
            var candidate = candidate
            candidate.isSelected = isSelected
            return candidate
        }
    }

    private func importSelectedPhraseDiscoveryCandidates() {
        let selected = phraseDiscoveryCandidates.filter(\.isSelected)
        let selectedWords = Set(selected.map { $0.phrase.trimmingCharacters(in: .whitespacesAndNewlines) })
        let existingBeforeSave = store.existingPhraseWords(in: selectedWords)
        var added = 0
        var skipped = 0
        var errors: [String] = []

        for candidate in selected {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard PhraseDiscoveryParser.isValidPhrase(phrase) else {
                skipped += 1
                continue
            }
            guard !existingBeforeSave.contains(phrase), store.mergedPhrase(for: phrase) == nil else {
                skipped += 1
                continue
            }
            do {
                try store.addCustomPhrase(
                    word: phrase,
                    pinyin: candidate.pinyin,
                    meanings: candidate.meaning,
                    notes: nil,
                    refreshViews: false
                )
                added += 1
            } catch {
                errors.append("\(phrase): \(error.localizedDescription)")
            }
        }

        store.refreshPhraseOverlayViews()
        let selectedIDs = Set(selected.map(\.id))
        phraseDiscoveryCandidates = phraseDiscoveryCandidates.map { candidate in
            var candidate = candidate
            if selectedIDs.contains(candidate.id) {
                candidate.isSelected = false
            }
            return candidate
        }
        phraseDiscoveryMessage = "Selected \(selected.count). Added \(added). Skipped \(skipped).\(errors.isEmpty ? "" : " Errors: \(errors.joined(separator: "; "))")"
    }

    private func resetPhraseDiscovery() {
        phraseDiscoveryOutput = ""
        phraseDiscoveryCandidates = []
        phraseDiscoveryStats = PhraseDiscoveryStats()
        phraseDiscoveryMessage = nil
    }

    private func chatGPTURL(prompt: String) -> URL? {
        var components = URLComponents(string: "https://chatgpt.com/")
        components?.queryItems = [
            URLQueryItem(name: "q", value: prompt)
        ]
        return components?.url
    }

    private func captureSection<Content: View>(_ title: String, @ViewBuilder content: () -> Content) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)
            content()
        }
    }

    @MainActor
    private func loadAndRecognize(_ item: PhotosPickerItem?) async {
        guard let item else { return }
        do {
            guard let data = try await item.loadTransferable(type: Data.self),
                  let image = UIImage(data: data) else {
                throw NSError(domain: "Radix", code: 3002, userInfo: [NSLocalizedDescriptionKey: "The selected image could not be loaded."])
            }
            await recognize(image)
        } catch {
            errorMessage = error.localizedDescription
        }
    }

    @MainActor
    private func recognize(_ image: UIImage) async {
        isProcessing = true
        errorMessage = nil
        statusMessage = nil
        defer { isProcessing = false }

        do {
            selectedImage = image
            let text = try await CaptureOCRService().recognizeText(in: image)
            let foundCharacters = CaptureTextExtractor.uniqueCharacters(in: text)
            let foundPhrases = CaptureTextExtractor.uniquePhrases(in: text)
            store.activeCaptureDraft = CaptureDraft(
                rawText: text,
                charactersText: foundCharacters.joined(separator: " "),
                phrasesText: foundPhrases.joined(separator: "\n")
            )
            gridPage = 0
            capturePreviewCharacter = nil
            captureDetailPreviewCharacter = nil
            resetPhraseDiscovery()
            statusMessage = foundCharacters.isEmpty ? "No Chinese characters found. You can edit the fields manually." : "Review, edit, then save what matters."
        } catch {
            errorMessage = error.localizedDescription
        }
    }

}

private struct PhraseDiscoveryCandidate: Identifiable, Hashable {
    let id = UUID()
    var phrase: String
    var pinyin: String
    var meaning: String
    var isSelected = true
}

private struct PhraseDiscoveryStats {
    var totalParsed = 0
    var duplicatesRemoved = 0
    var alreadyExisting = 0
    var invalidLines = 0
}

private struct PhraseDiscoveryParseResult {
    var candidates: [PhraseDiscoveryCandidate]
    var totalParsed: Int
    var duplicatesRemoved: Int
    var invalidLines: Int
}

private enum PhraseDiscoveryParser {
    static func parse(_ text: String) -> PhraseDiscoveryParseResult {
        var candidates: [PhraseDiscoveryCandidate] = []
        var seen = Set<String>()
        var totalParsed = 0
        var duplicatesRemoved = 0
        var invalidLines = 0

        for rawLine in text.components(separatedBy: .newlines) {
            guard let row = parseLine(rawLine) else {
                if !isIgnorableLine(rawLine) {
                    invalidLines += 1
                }
                continue
            }

            totalParsed += 1
            guard seen.insert(row.phrase).inserted else {
                duplicatesRemoved += 1
                continue
            }
            candidates.append(row)
        }

        return PhraseDiscoveryParseResult(
            candidates: candidates,
            totalParsed: totalParsed,
            duplicatesRemoved: duplicatesRemoved,
            invalidLines: invalidLines
        )
    }

    static func isValidPhrase(_ phrase: String) -> Bool {
        let trimmed = phrase.trimmingCharacters(in: .whitespacesAndNewlines)
        guard (2...4).contains(trimmed.count) else { return false }
        return trimmed.allSatisfy { character in
            character.unicodeScalars.contains {
                (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0x20000...0x2EBEF).contains($0.value)
            }
        }
    }

    private static func parseLine(_ rawLine: String) -> PhraseDiscoveryCandidate? {
        let line = cleanedLine(rawLine)
        guard !line.isEmpty, !isMarkdownSeparator(line) else { return nil }

        let parts: [String]
        if line.contains("|") {
            parts = line
                .split(separator: "|", omittingEmptySubsequences: false)
                .map { cleanCell(String($0)) }
        } else if line.contains("\t") {
            parts = line
                .split(separator: "\t", omittingEmptySubsequences: false)
                .map { cleanCell(String($0)) }
        } else {
            parts = splitLooseLine(line)
        }

        guard let first = parts.first else { return nil }
        let phrase = cleanPhrase(first)
        guard isValidPhrase(phrase) else { return nil }

        let pinyin = parts.indices.contains(1) ? cleanCell(parts[1]) : ""
        let meaning = parts.indices.contains(2)
            ? parts[2...].map(cleanCell).filter { !$0.isEmpty }.joined(separator: " | ")
            : ""

        return PhraseDiscoveryCandidate(phrase: phrase, pinyin: pinyin, meaning: meaning)
    }

    private static func cleanedLine(_ rawLine: String) -> String {
        var line = rawLine.trimmingCharacters(in: .whitespacesAndNewlines)
        while line.hasPrefix("|") { line.removeFirst() }
        while line.hasSuffix("|") { line.removeLast() }
        line = line.trimmingCharacters(in: .whitespacesAndNewlines)
        line = line.replacingOccurrences(
            of: #"^\s*(?:[-*•]\s+|\d+[.)]\s*)"#,
            with: "",
            options: .regularExpression
        )
        return line.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func cleanCell(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "`")))
    }

    private static func cleanPhrase(_ value: String) -> String {
        cleanCell(value)
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func isMarkdownSeparator(_ line: String) -> Bool {
        let compact = line.replacingOccurrences(of: "|", with: "")
            .replacingOccurrences(of: ":", with: "")
            .replacingOccurrences(of: "-", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return compact.isEmpty
    }

    private static func isIgnorableLine(_ rawLine: String) -> Bool {
        let line = cleanedLine(rawLine)
        guard !line.isEmpty, !isMarkdownSeparator(line) else { return true }
        let hasChinese = line.contains { character in
            character.unicodeScalars.contains {
                (0x3400...0x4DBF).contains($0.value)
                || (0x4E00...0x9FFF).contains($0.value)
                || (0x20000...0x2EBEF).contains($0.value)
            }
        }
        if !hasChinese { return true }
        return false
    }

    private static func splitLooseLine(_ line: String) -> [String] {
        guard let phraseRange = line.range(
            of: #"[\u{3400}-\u{4DBF}\u{4E00}-\u{9FFF}\u{20000}-\u{2EBEF}]{2,4}"#,
            options: .regularExpression
        ) else {
            return []
        }
        let phrase = String(line[phraseRange])
        let rest = line[phraseRange.upperBound...]
            .trimmingCharacters(in: .whitespacesAndNewlines.union(CharacterSet(charactersIn: "-–—:：")))
        guard !rest.isEmpty else { return [phrase] }
        return [phrase, "", rest]
    }
}

private struct CameraCaptureView: UIViewControllerRepresentable {
    let onImage: (UIImage) -> Void
    @Environment(\.dismiss) private var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = .camera
        picker.cameraCaptureMode = .photo
        picker.delegate = context.coordinator
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) { }

    func makeCoordinator() -> Coordinator {
        Coordinator(onImage: onImage, dismiss: dismiss)
    }

    final class Coordinator: NSObject, UINavigationControllerDelegate, UIImagePickerControllerDelegate {
        private let onImage: (UIImage) -> Void
        private let dismiss: DismissAction

        init(onImage: @escaping (UIImage) -> Void, dismiss: DismissAction) {
            self.onImage = onImage
            self.dismiss = dismiss
        }

        func imagePickerController(_ picker: UIImagePickerController, didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                onImage(image)
            }
            dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            dismiss()
        }
    }
}
