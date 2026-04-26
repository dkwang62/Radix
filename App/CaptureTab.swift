import SwiftUI
import PhotosUI
import UIKit
import UniformTypeIdentifiers

struct CaptureTab: View {
    @EnvironmentObject private var store: RadixStore
    @Environment(\.openURL) private var openURL
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var showImageFileImporter = false
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
    @State private var phraseDiscoveryAddedPhrases: [PhraseDiscoveryCandidate] = []
    @State private var phraseDiscoveryPromptCopied = false
    @State private var phraseDiscoveryImportedCount = 0
    @State private var phraseMode: CapturePhraseMode = .apple
    @State private var parserSource: PhraseParserSource = .appleCandidates
    @State private var parserInputPhrases: [String] = []
    @State private var showOCRCollectionSheet = false
    @State private var ocrCollectionName = ""

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

    private var canBuildParserPrompt: Bool {
        switch parserSource {
        case .appleCandidates:
            return !parserInputPhrases.isEmpty
        case .chatGPTDerived:
            return !store.activeCaptureDraft.rawText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private var captureWorkflowSteps: [CaptureWorkflowStep] {
        [
            CaptureWorkflowStep(
                title: "Choose",
                detail: parserSource.shortTitle,
                isComplete: true,
                systemImage: "checkmark.circle"
            ),
            CaptureWorkflowStep(
                title: "Copy",
                detail: phraseDiscoveryPromptCopied ? "Prompt copied" : "Open ChatGPT",
                isComplete: phraseDiscoveryPromptCopied,
                systemImage: "doc.on.doc"
            ),
            CaptureWorkflowStep(
                title: "Paste",
                detail: phraseDiscoveryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "ChatGPT answer" : "Answer pasted",
                isComplete: !phraseDiscoveryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                systemImage: "doc.on.clipboard"
            ),
            CaptureWorkflowStep(
                title: "Add",
                detail: phraseDiscoveryImportedCount == 0 ? "To My Phrases" : "\(phraseDiscoveryImportedCount) added",
                isComplete: phraseDiscoveryImportedCount > 0,
                systemImage: "plus.circle"
            ),
            CaptureWorkflowStep(
                title: "Check",
                detail: phraseDiscoveryCandidates.isEmpty ? "No list yet" : "\(phraseDiscoveryCandidates.count) shown",
                isComplete: !phraseDiscoveryCandidates.isEmpty,
                systemImage: "checklist"
            )
        ]
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
        .fileImporter(
            isPresented: $showImageFileImporter,
            allowedContentTypes: [.image],
            allowsMultipleSelection: false
        ) { result in
            Task { await loadAndRecognizeFile(result) }
        }
        .sheet(isPresented: $showCamera) {
            CameraCaptureView { image in
                showCamera = false
                Task { await recognize(image) }
            }
        }
        .sheet(isPresented: $showOCRCollectionSheet) {
            ocrCollectionSheet
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

            Button {
                showImageFileImporter = true
            } label: {
                Text(filePickerTitle)
            }
            .buttonStyle(.bordered)
            .disabled(isProcessing)
        }
    }

    private var filePickerTitle: String {
        #if targetEnvironment(macCatalyst)
        return "Finder"
        #else
        return "Files"
        #endif
    }

    private var defaultOCRCollectionName: String {
        "OCR Page \(Date().formatted(date: .numeric, time: .shortened))"
    }

    private var ocrCollectionSheet: some View {
        NavigationStack {
            Form {
                Section("Page") {
                    TextField("Name", text: $ocrCollectionName)
                    Text("\(characters.count) unique Chinese characters will be saved.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .navigationTitle("Save Page")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") {
                        showOCRCollectionSheet = false
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        saveOCRCollection()
                    }
                    .disabled(characters.isEmpty)
                }
            }
        }
    }

    private func saveOCRCollection() {
        guard let collection = store.createCollection(
            name: ocrCollectionName,
            sourceText: store.activeCaptureDraft.charactersText,
            sourceType: .ocr
        ) else { return }
        store.selectBrowseCollection(id: collection.id)
        statusMessage = "Saved \(collection.name) with \(collection.characters.count) characters."
        showOCRCollectionSheet = false
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
            captureCharactersSection(scrollToTop: scrollToTop)

            switch phraseMode {
            case .apple:
                appleDerivedPhraseSection
            case .parser:
                phraseDiscoveryImportSection
            }
        }
    }

    private func captureCharactersSection(scrollToTop: @escaping () -> Void) -> some View {
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

            HStack(spacing: 10) {
                if phraseMode == .apple {
                    Button("Remember Characters") {
                        for character in characters {
                            store.pushRootBreadcrumb(character)
                        }
                        statusMessage = "Characters added to Remembered."
                    }
                    .buttonStyle(.bordered)
                    .disabled(characters.isEmpty)

                    Button("Save Page") {
                        ocrCollectionName = defaultOCRCollectionName
                        showOCRCollectionSheet = true
                    }
                    .buttonStyle(.bordered)
                    .disabled(characters.isEmpty)

                    Button {
                        openAILinkTask4()
                    } label: {
                        Label("Isolate Phrases with AI", systemImage: "sparkles")
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(characters.isEmpty)
                } else {
                    Button {
                        phraseMode = .apple
                    } label: {
                        Label("Back to Apple-Derived Phrases", systemImage: "chevron.left")
                    }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private var appleDerivedPhraseSection: some View {
        captureSection("Apple-Derived Phrases") {
            VStack(alignment: .leading, spacing: 12) {
                phraseWorkflowChoicePanel
                addChatGPTAnswerPanel

                VStack(alignment: .leading, spacing: 6) {
                    Text("Existing Radix Phrases")
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                    if existingPhrases.isEmpty {
                        Text("No existing Radix phrases found from this image.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                    } else {
                        phraseTable(existingPhrases)
                    }
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text("OCR Phrase Candidates")
                        .font(ResponsiveFont.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
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
            }
        }
    }

    private var phraseWorkflowChoicePanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Choose what to add to My Phrases")
                .font(ResponsiveFont.caption.weight(.semibold))
            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 180), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button {
                    startApplePhraseParser(phrases: newPhrases)
                } label: {
                    Label("Ask ChatGPT", systemImage: "text.magnifyingglass")
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
                .buttonStyle(.bordered)
                .disabled(newPhrases.isEmpty)
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var addChatGPTAnswerPanel: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add ChatGPT Answer to My Phrases")
                .font(ResponsiveFont.caption.weight(.semibold))

            Text("Paste one phrase or a batch from ChatGPT. Use this format: phrase | pinyin | English meaning.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)

            TextEditor(text: $phraseDiscoveryOutput)
                .font(ResponsiveFont.body)
                .frame(minHeight: 110)
                .padding(6)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
                .overlay(
                    RoundedRectangle(cornerRadius: 8)
                        .stroke(Color(.separator), lineWidth: 0.5)
                )

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                Button {
                    pasteAndAddPhraseDiscoveryOutput()
                } label: {
                    Label("Paste ChatGPT Answer and Add", systemImage: "doc.on.clipboard")
                }
                .buttonStyle(.borderedProminent)

                Button("Add from Box") {
                    addPhraseDiscoveryOutputToMyPhrases()
                }
                .buttonStyle(.bordered)
                .disabled(phraseDiscoveryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                Button("Clear") {
                    clearPhraseDiscoveryInput()
                }
                .buttonStyle(.bordered)
                .disabled(phraseDiscoveryOutput.isEmpty && phraseDiscoveryMessage == nil)
            }

            if let phraseDiscoveryMessage {
                Text(phraseDiscoveryMessage)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            if !phraseDiscoveryAddedPhrases.isEmpty {
                addedPhraseResultList
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var phraseDiscoveryImportSection: some View {
        captureSection(parserSource.title) {
            VStack(alignment: .leading, spacing: 10) {
                captureWorkflowProgress

                VStack(alignment: .leading, spacing: 5) {
                    Text(parserSource.guidanceTitle)
                        .font(ResponsiveFont.caption.weight(.semibold))
                    Text(parserSource.guidanceDetail(count: parserInputPhrases.count))
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))

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

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 150), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    Button("Open ChatGPT") {
                        copyPhraseDiscoveryPrompt()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(!canBuildParserPrompt)

                    Button {
                        pasteAndAddPhraseDiscoveryOutput()
                    } label: {
                        Label("Paste ChatGPT Answer and Add", systemImage: "doc.on.clipboard")
                    }
                    .buttonStyle(.bordered)

                    Button("Clear") {
                        resetPhraseDiscovery(keepMode: true)
                    }
                    .buttonStyle(.bordered)
                    .disabled(phraseDiscoveryOutput.isEmpty && phraseDiscoveryCandidates.isEmpty)
                }

                if phraseDiscoveryPromptCopied &&
                    phraseDiscoveryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
                    phraseDiscoveryCandidates.isEmpty {
                    ProgressView("Waiting for ChatGPT answer...")
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 6)
                }

                Text("Paste ChatGPT's answer here. Radix will add the phrases to My Phrases.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

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

                LazyVGrid(
                    columns: [GridItem(.adaptive(minimum: 120), spacing: 8)],
                    alignment: .leading,
                    spacing: 8
                ) {
                    Button("Add from Box") {
                        addPhraseDiscoveryOutputToMyPhrases()
                    }
                    .buttonStyle(.bordered)
                    .disabled(phraseDiscoveryOutput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)

                    Button("Preview Answer") {
                        readPhraseDiscoveryOutput(addImmediately: false)
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

                if !phraseDiscoveryAddedPhrases.isEmpty {
                    addedPhraseResultList
                }

                HStack {
                    Spacer()
                    Button("Add Selected to My Phrases") {
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
        let sourceTitle = parserSource == .appleCandidates ? "Input" : "Known in OCR"
        let sourceCount = parserSource == .appleCandidates ? parserInputPhrases.count : knownCount
        return LazyVGrid(
            columns: [GridItem(.adaptive(minimum: 130), spacing: 8)],
            alignment: .leading,
            spacing: 8
        ) {
            discoveryStatChip(sourceTitle, sourceCount)
            discoveryStatChip("Read", phraseDiscoveryStats.totalParsed)
            discoveryStatChip("Duplicates", phraseDiscoveryStats.duplicatesRemoved)
            discoveryStatChip("Existing", phraseDiscoveryStats.alreadyExisting)
            discoveryStatChip("Invalid", phraseDiscoveryStats.invalidLines)
            discoveryStatChip("New", phraseDiscoveryCandidates.count)
            discoveryStatChip("Selected", selectedCount)
        }
    }

    private var captureWorkflowProgress: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Add Phrases Steps")
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.secondary)

            LazyVGrid(
                columns: [GridItem(.adaptive(minimum: 118), spacing: 8)],
                alignment: .leading,
                spacing: 8
            ) {
                ForEach(captureWorkflowSteps) { step in
                    captureWorkflowStepChip(step)
                }
            }
        }
        .padding(10)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func captureWorkflowStepChip(_ step: CaptureWorkflowStep) -> some View {
        HStack(spacing: 8) {
            Image(systemName: step.isComplete ? "checkmark.circle.fill" : step.systemImage)
                .font(ResponsiveFont.caption)
                .foregroundStyle(step.isComplete ? Color.green : Color.secondary)

            VStack(alignment: .leading, spacing: 1) {
                Text(step.title)
                    .font(ResponsiveFont.caption.weight(.semibold))
                Text(step.detail)
                    .font(ResponsiveFont.caption2)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 7)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(step.isComplete ? Color.green.opacity(0.12) : Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(step.isComplete ? Color.green.opacity(0.35) : Color(.separator), lineWidth: 0.5)
        )
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

    private var addedPhraseResultList: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Added to My Phrases")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(.secondary)

            VStack(spacing: 0) {
                ForEach(phraseDiscoveryAddedPhrases) { candidate in
                    addedPhraseResultRow(candidate)
                    Divider()
                }
            }
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
    }

    private func addedPhraseResultRow(_ candidate: PhraseDiscoveryCandidate) -> some View {
        HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 3) {
                Text(candidate.phrase)
                    .font(ResponsiveFont.body.bold())
                if !candidate.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(candidate.pinyin)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                if !candidate.meaning.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(candidate.meaning)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Button("Delete", role: .destructive) {
                deleteAddedPhrase(candidate)
            }
            .buttonStyle(.bordered)
            .controlSize(.mini)
            .font(ResponsiveFont.caption2.weight(.semibold))
        }
        .padding(8)
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

            Button("Ask ChatGPT") {
                startApplePhraseParser(phrases: [phrase])
            }
            .buttonStyle(.borderedProminent)
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

    private func startApplePhraseParser(phrases: [String]) {
        let normalized = CaptureTextExtractor.uniquePhrases(from: phrases)
        guard !normalized.isEmpty else { return }
        parserInputPhrases = normalized
        parserSource = .appleCandidates
        phraseMode = .parser
        resetPhraseDiscovery(keepMode: true)
        copyPhraseDiscoveryPrompt()
    }

    private func openAILinkTask4() {
        if let collection = store.createCollection(
            name: defaultOCRCollectionName,
            sourceText: store.activeCaptureDraft.charactersText,
            sourceType: .ocr
        ) {
            store.goToAILinkTask4(collection: collection)
            statusMessage = "AI Link Task 4 opened with \(collection.name)."
        } else {
            store.goToAILinkTask4FromCapture(characters: characters)
            statusMessage = "AI Link Task 4 opened. ChatGPT will receive the Apple Vision characters."
        }
    }

    private func startChatGPTPhraseDiscovery() {
        parserInputPhrases = []
        parserSource = .chatGPTDerived
        phraseMode = .parser
        resetPhraseDiscovery(keepMode: true)
        copyPhraseDiscoveryPrompt()
    }

    private func copyPhraseDiscoveryPrompt() {
        let prompt = makePhraseDiscoveryPrompt()
        #if canImport(UIKit)
        UIPasteboard.general.string = prompt
        #endif
        if let url = chatGPTURL(prompt: prompt) {
            openURL(url)
        }
        phraseDiscoveryPromptCopied = true
        phraseDiscoveryMessage = "ChatGPT opened. Copy its answer, then come back and tap Paste ChatGPT Answer and Add."
    }

    private func makePhraseDiscoveryPrompt() -> String {
        switch parserSource {
        case .appleCandidates:
            return makeApplePhraseParserPrompt()
        case .chatGPTDerived:
            return makeChatGPTPhraseDiscoveryPrompt()
        }
    }

    private func makeApplePhraseParserPrompt() -> String {
        let phraseList = parserInputPhrases.joined(separator: "\n")

        return """
        For each Chinese phrase below, provide pinyin with tone marks and a concise English meaning.

        Output only in this format:
        Phrase | Pinyin | Concise English meaning

        Phrases:
        \(phraseList)

        Important:
        - Preserve each phrase exactly as written.
        - Do not add phrases that are not in the list.
        - Do not include headings, numbering, bullets, markdown tables, or explanations.
        - If a phrase is invalid or not a real phrase, omit it.
        """
    }

    private func makeChatGPTPhraseDiscoveryPrompt() -> String {
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

    private func readPhraseDiscoveryOutput(addImmediately: Bool) {
        phraseDiscoveryImportedCount = 0
        let parsed = PhraseDiscoveryParser.parse(phraseDiscoveryOutput)
        let existingWords = store.existingPhraseWords(in: Set(parsed.candidates.map(\.phrase)))
        phraseDiscoveryCandidates = parsed.candidates
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
        if addImmediately {
            addPhraseDiscoveryCandidates(phraseDiscoveryCandidates)
        } else {
            phraseDiscoveryMessage = phraseDiscoveryCandidates.isEmpty
                ? "Radix could not read any phrases from that answer."
                : "Radix found \(phraseDiscoveryCandidates.count) phrase\(phraseDiscoveryCandidates.count == 1 ? "" : "s"). You can edit the list, then tap Add Selected to My Phrases."
        }
    }

    private func addPhraseDiscoveryOutputToMyPhrases() {
        readPhraseDiscoveryOutput(addImmediately: true)
    }

    private func pasteAndAddPhraseDiscoveryOutput() {
        #if canImport(UIKit)
        let clipboardText = UIPasteboard.general.string ?? ""
        #else
        let clipboardText = ""
        #endif

        let trimmed = clipboardText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            phraseDiscoveryMessage = "Clipboard is empty."
            return
        }

        phraseDiscoveryOutput = clipboardText
        readPhraseDiscoveryOutput(addImmediately: true)
    }

    private func clearPhraseDiscoveryInput() {
        phraseDiscoveryOutput = ""
        phraseDiscoveryCandidates = []
        phraseDiscoveryAddedPhrases = []
        phraseDiscoveryStats = PhraseDiscoveryStats()
        phraseDiscoveryMessage = nil
        phraseDiscoveryImportedCount = 0
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
        addPhraseDiscoveryCandidates(selected)
    }

    private func addPhraseDiscoveryCandidates(_ selected: [PhraseDiscoveryCandidate]) {
        var added = 0
        var skipped = 0
        var addedCandidates: [PhraseDiscoveryCandidate] = []
        var errors: [String] = []
        var seen = Set<String>()

        for candidate in selected {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard PhraseDiscoveryParser.isValidPhrase(phrase) else {
                skipped += 1
                continue
            }
            guard seen.insert(phrase).inserted else {
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
                addedCandidates.append(candidate)
            } catch {
                errors.append("\(phrase): \(error.localizedDescription)")
            }
        }

        store.refreshPhraseOverlayViews()
        phraseDiscoveryImportedCount = added
        phraseDiscoveryAddedPhrases = mergeAddedPhraseResults(phraseDiscoveryAddedPhrases, addedCandidates)
        let selectedIDs = Set(selected.map(\.id))
        phraseDiscoveryCandidates = phraseDiscoveryCandidates.map { candidate in
            var candidate = candidate
            if selectedIDs.contains(candidate.id) {
                candidate.isSelected = false
            }
            return candidate
        }
        if selected.isEmpty {
            phraseDiscoveryMessage = "No new phrases were found in the ChatGPT answer."
        } else if added == 0 {
            phraseDiscoveryMessage = "Radix read \(selected.count) phrase\(selected.count == 1 ? "" : "s"), but none were added to My Phrases. Skipped \(skipped).\(errors.isEmpty ? "" : " Errors: \(errors.joined(separator: "; "))")"
        } else {
            phraseDiscoveryMessage = "Added or updated \(added) in My Phrases. Delete any phrase below that you do not want to keep.\(skipped == 0 ? "" : " Skipped \(skipped).")\(errors.isEmpty ? "" : " Errors: \(errors.joined(separator: "; "))")"
        }
    }

    private func mergeAddedPhraseResults(_ current: [PhraseDiscoveryCandidate], _ newItems: [PhraseDiscoveryCandidate]) -> [PhraseDiscoveryCandidate] {
        var seen = Set<String>()
        var merged: [PhraseDiscoveryCandidate] = []
        for candidate in newItems + current {
            let phrase = candidate.phrase.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !phrase.isEmpty, seen.insert(phrase).inserted else { continue }
            merged.append(candidate)
        }
        return merged
    }

    private func deleteAddedPhrase(_ candidate: PhraseDiscoveryCandidate) {
        store.removeDataEditPhrase(word: candidate.phrase)
        phraseDiscoveryAddedPhrases.removeAll { $0.phrase == candidate.phrase }
        phraseDiscoveryImportedCount = phraseDiscoveryAddedPhrases.count
        phraseDiscoveryMessage = "Removed \(candidate.phrase) from My Phrases."
    }

    private func resetPhraseDiscovery(keepMode: Bool = false) {
        phraseDiscoveryOutput = ""
        phraseDiscoveryCandidates = []
        phraseDiscoveryAddedPhrases = []
        phraseDiscoveryStats = PhraseDiscoveryStats()
        phraseDiscoveryMessage = nil
        phraseDiscoveryPromptCopied = false
        phraseDiscoveryImportedCount = 0
        if !keepMode {
            parserInputPhrases = []
            parserSource = .appleCandidates
            phraseMode = .apple
        }
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
    private func loadAndRecognizeFile(_ result: Result<[URL], Error>) async {
        do {
            guard let url = try result.get().first else { return }
            let canAccess = url.startAccessingSecurityScopedResource()
            defer {
                if canAccess {
                    url.stopAccessingSecurityScopedResource()
                }
            }

            let data = try Data(contentsOf: url)
            guard let image = UIImage(data: data) else {
                throw NSError(domain: "Radix", code: 3003, userInfo: [NSLocalizedDescriptionKey: "The selected file is not a readable image."])
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

private struct CaptureWorkflowStep: Identifiable {
    var id: String { title }
    let title: String
    let detail: String
    let isComplete: Bool
    let systemImage: String
}

private enum CapturePhraseMode: Equatable {
    case apple
    case parser
}

private enum PhraseParserSource: Equatable {
    case appleCandidates
    case chatGPTDerived

    var title: String {
        switch self {
        case .appleCandidates:
            return "Add Apple Candidates to My Phrases"
        case .chatGPTDerived:
            return "Add ChatGPT Suggestions to My Phrases"
        }
    }

    var shortTitle: String {
        switch self {
        case .appleCandidates:
            return "Apple candidates"
        case .chatGPTDerived:
            return "More phrases"
        }
    }

    var guidanceTitle: String {
        switch self {
        case .appleCandidates:
            return "You chose Apple-derived phrases."
        case .chatGPTDerived:
            return "You chose ChatGPT suggestions."
        }
    }

    func guidanceDetail(count: Int) -> String {
        switch self {
        case .appleCandidates:
            let phraseText = count == 1 ? "1 phrase" : "\(count) phrases"
            return "Radix copies \(phraseText) to ChatGPT so it can add pinyin and meaning. Copy ChatGPT's answer, then tap Paste ChatGPT Answer and Add."
        case .chatGPTDerived:
            return "Radix copies the OCR text to ChatGPT so it can find more phrases with pinyin and meaning. Copy ChatGPT's answer, then tap Paste ChatGPT Answer and Add."
        }
    }
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
        guard (1...12).contains(trimmed.count) else { return false }
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

        guard !isHeaderRow(parts) else { return nil }
        guard let first = parts.first else { return nil }
        let phrase = cleanPhrase(first)
        guard isValidPhrase(phrase) else { return nil }

        let pinyin = parts.indices.contains(1) ? cleanLabeledValue(parts[1]) : ""
        let meaning = parts.indices.contains(2)
            ? parts[2...].map(cleanLabeledValue).filter { !$0.isEmpty }.joined(separator: " | ")
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
        let cleaned = cleanLabeledValue(value)
            .trimmingCharacters(in: CharacterSet.punctuationCharacters.union(.symbols))
            .trimmingCharacters(in: .whitespacesAndNewlines)
        if isValidPhrase(cleaned) {
            return cleaned
        }
        let matches = chineseRuns(in: cleaned)
        return matches.last ?? cleaned
    }

    private static func cleanLabeledValue(_ value: String) -> String {
        cleanCell(value)
            .replacingOccurrences(
                of: #"^\s*(?:phrase|word|pinyin|meaning|english|definition|短语|词语|词|拼音|意思|含义|英文)\s*[:：]\s*"#,
                with: "",
                options: [.regularExpression, .caseInsensitive]
            )
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func chineseRuns(in value: String) -> [String] {
        let pattern = #"[\u{3400}-\u{4DBF}\u{4E00}-\u{9FFF}\u{20000}-\u{2EBEF}]{1,12}"#
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let nsRange = NSRange(value.startIndex..<value.endIndex, in: value)
        return regex.matches(in: value, range: nsRange).compactMap { match in
            guard let range = Range(match.range, in: value) else { return nil }
            return String(value[range])
        }
    }

    private static func isHeaderRow(_ parts: [String]) -> Bool {
        let normalized = parts
            .map { cleanCell($0).lowercased().trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        guard !normalized.isEmpty else { return false }
        let headerWords: Set<String> = [
            "phrase", "word", "pinyin", "meaning", "english", "definition",
            "短语", "词语", "词", "拼音", "意思", "含义", "英文", "英文含义"
        ]
        return normalized.allSatisfy { headerWords.contains($0) }
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
