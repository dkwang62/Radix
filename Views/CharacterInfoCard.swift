import SwiftUI

struct CharacterInfoCard: View {
    @EnvironmentObject private var store: RadixStore
    let item: ComponentItem
    let variants: [String]
    let onSelectVariant: ((String) -> Void)?
    let showClearButton: Bool
    let onShowPhrases: (() -> Void)?
    let onClear: (() -> Void)?
    @State private var showFrequencyGuide = false
    @State private var activeChipGuide: ChipGuide?
    @Binding var variantIndex: Int

    private let idcChars: Set<Character> = ["⿰", "⿱", "⿲", "⿳", "⿴", "⿵", "⿶", "⿷", "⿸", "⿹", "⿺", "⿻"]

    init(
        item: ComponentItem,
        variants: [String],
        variantIndex: Binding<Int>,
        showClearButton: Bool = false,
        onShowPhrases: (() -> Void)? = nil,
        onClear: (() -> Void)? = nil,
        onSelectVariant: ((String) -> Void)? = nil
    ) {
        self.item = item
        self.variants = variants
        self._variantIndex = variantIndex
        self.showClearButton = showClearButton
        self.onShowPhrases = onShowPhrases
        self.onClear = onClear
        self.onSelectVariant = onSelectVariant
    }

    // Backwards-compat init for call sites still passing a single counterpart
    init(item: ComponentItem, counterpart: String?, onSelectCounterpart: ((String) -> Void)? = nil) {
        self.item = item
        self.variants = counterpart.map { [$0] } ?? []
        self._variantIndex = .constant(0)
        self.showClearButton = false
        self.onShowPhrases = nil
        self.onClear = nil
        self.onSelectVariant = onSelectCounterpart
    }

    private var currentVariant: String? {
        guard !variants.isEmpty else { return nil }
        return variants[variantIndex % variants.count]
    }

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        content
        .padding(16)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .overlay(
            RoundedRectangle(cornerRadius: 16)
                .stroke(Color(.separator), lineWidth: 1)
        )
        .onChange(of: item.character) { _, _ in
            variantIndex = 0
        }
    }

    private var content: some View {
        standardContent
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow(
                characterSize: isPhone ? 32 : 40,
                pinyinFont: isPhone ? ResponsiveFont.title3.bold() : ResponsiveFont.title.bold()
            )

            actionRow

            HStack(alignment: .center, spacing: 8) {
                tierButton
                Spacer(minLength: 0)
            }

            HStack(spacing: 6) {
                chipButton("字 \(item.usageCount)", guide: .usageCount)
                if let strokes = item.strokes {
                    chipButton("✍️ \(strokes)", guide: .strokes)
                }
            }

            if !structurePartsText.isEmpty || !item.radical.isEmpty {
                HStack(spacing: 6) {
                    if !structurePartsText.isEmpty {
                        chipButton(structurePartsText, guide: .structure)
                    }
                    if !item.radical.isEmpty {
                        chipButton(item.radical, guide: .radical)
                    }
                }
            }

            definitionAndNotes
        }
    }

    private var actionRow: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 6) {
                Spacer(minLength: 0)
                notesButton
                phrasesButton
                componentsButton
                if showClearButton, onClear != nil {
                    clearPreviewButton
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private func headerRow(
        characterSize: CGFloat,
        pinyinFont: Font
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            Text(item.character)
                .font(.system(size: characterSize, weight: .bold))
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)

            Text(displayPinyin)
                .font(pinyinFont)
                .foregroundStyle(Color.orange)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Spacer(minLength: 0)
            favoritesButton
            speechToggleButton
        }
    }

    private var notesButton: some View {
        Button {
            store.openQuickCharacterEditor(item.character)
        } label: {
            actionLabel("✏️", systemImage: "note.text")
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
    }

    private var phrasesButton: some View {
        Button {
            store.refreshPhrases(for: item.character)
            onShowPhrases?()
        } label: {
            actionLabel("词", systemImage: "text.quote")
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
    }

    private var componentsButton: some View {
        Button {
            store.goToRoots(character: item.character)
        } label: {
            actionLabel("拆", systemImage: "tree")
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
    }

    private var speechToggleButton: some View {
        Button {
            store.speechEnabled.toggle()
        } label: {
            Image(systemName: store.speechMenuSymbolName)
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
        .help(store.speechEnabled ? "Turn character speech off" : "Turn character speech on")
    }

    private var favoritesButton: some View {
        Button {
            store.setFavorite(character: item.character, isFavorite: !store.isFavorite(item.character))
        } label: {
            Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
                .foregroundStyle(store.isFavorite(item.character) ? .yellow : .secondary)
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
        .help(store.isFavorite(item.character) ? "Remove from favorites" : "Add to favorites")
    }

    private var clearPreviewButton: some View {
        Button {
            onClear?()
        } label: {
            if isPhone {
                Text("❌")
            } else {
                Text("Clear Preview")
            }
        }
        .buttonStyle(.bordered)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
    }

    @ViewBuilder
    private func actionLabel(_ title: String, systemImage: String) -> some View {
        if isPhone {
            Text(title)
                .lineLimit(1)
                .minimumScaleFactor(0.75)
                .frame(minHeight: 28)
        } else {
            Text(title)
        }
    }

    private var tierButton: some View {
        Button {
            showFrequencyGuide = true
        } label: {
            HStack(spacing: 6) {
                tierChip(for: item.tier)
                Text(tierRecommendation)
                    .font(ResponsiveFont.caption2.italic())
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .buttonStyle(.plain)
        .popover(isPresented: $showFrequencyGuide, arrowEdge: .bottom) {
            tierGuideView
        }
    }

    private func chipButton(_ text: String, guide: ChipGuide) -> some View {
        Button {
            activeChipGuide = guide
        } label: {
            chip(text)
        }
        .buttonStyle(.plain)
        .popover(isPresented: chipGuideBinding(for: guide), arrowEdge: .bottom) {
            chipGuideView(for: guide)
                .applyCompactPopoverStyle()
        }
    }

    private func chipGuideBinding(for guide: ChipGuide) -> Binding<Bool> {
        Binding(
            get: { activeChipGuide == guide },
            set: { isPresented in
                if isPresented {
                    activeChipGuide = guide
                } else if activeChipGuide == guide {
                    activeChipGuide = nil
                }
            }
        )
    }

    private var tierGuideView: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Character Learning Guide")
                .font(ResponsiveFont.headline)
            
            guideRow(tier: "Tier 1", label: "Core Literacy", desc: "Everyday survival characters. Essential for everyone.")
            guideRow(tier: "Tier 2", label: "Fluency Core", desc: "Required for reading newspapers and media comfortably.")
            guideRow(tier: "Tier 3", label: "Educated Native", desc: "Required for university-level reading and formal writing.")
            guideRow(tier: "Tier 4", label: "Academic/Pro", desc: "Specialized, technical, or research-heavy characters.")
            guideRow(tier: "Tier 5", label: "Niche/Rare", desc: "Rare names, dialect, or archaic forms. Safe to ignore.")
        }
        .font(ResponsiveFont.subheadline)
        .padding(16)
        .frame(maxWidth: 380, alignment: .leading)
    }

    private func guideRow(tier: String, label: String, desc: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text("\(tier): \(label)")
                .fontWeight(.bold)
            Text(desc)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func chipGuideView(for guide: ChipGuide) -> some View {
        Text(guide.description(for: item))
            .font(chipGuideFont)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
    }

    private var displayPinyin: String {
        let joined = item.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "—" : joined
    }

    private var structurePartsText: String {
        item.decomposition.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var etymologyText: String {
        [item.etymologyHint, item.etymologyDetails]
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    private var notesText: String {
        item.notes.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private var tierLabel: String {
        "Tier \(item.tier)"
    }

    private var tierColor: Color {
        switch item.tier {
        case 1: return .green
        case 2: return .teal
        case 3: return .blue
        case 4: return .orange
        default: return .secondary
        }
    }

    private var tierRecommendation: String {
        switch item.tier {
        case 1: return "Essential"
        case 2: return "Strongly Recommended"
        case 3: return "For Intellectual Fluency"
        case 4: return "Academic Focus"
        default: return "Optional / Niche"
        }
    }

    private var definitionAndNotes: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(item.definition.isEmpty ? "No definition" : item.definition)
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.primary)
                .fixedSize(horizontal: false, vertical: true)

            if !etymologyText.isEmpty {
                Divider()
                Text(etymologyText)
                    .font(ResponsiveFont.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            if !notesText.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("✏️", systemImage: "note.text")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notesText)
                        .font(ResponsiveFont.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
    }

    private func tierChip(for tier: Int) -> some View {
        Text("Tier \(tier)")
            .font(ResponsiveFont.footnote.weight(.bold))
            .foregroundStyle(.white)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(tierColor)
            .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func chip(_ text: String) -> some View {
        Text(text)
            .font(chipFont)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    private var cardActionFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.caption.weight(.semibold)
        #else
        return ResponsiveFont.subheadline.weight(.semibold)
        #endif
    }

    private var cardActionControlSize: ControlSize {
        #if targetEnvironment(macCatalyst)
        return .small
        #else
        return .regular
        #endif
    }

    private var chipGuideFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.footnote
        #else
        return isPhone ? ResponsiveFont.subheadline : ResponsiveFont.subheadline
        #endif
    }

    private var chipFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.footnote.weight(.semibold)
        #else
        return isPhone ? ResponsiveFont.subheadline.weight(.semibold) : ResponsiveFont.footnote.weight(.semibold)
        #endif
    }
}

private extension View {
    @ViewBuilder
    func applyCompactPopoverStyle() -> some View {
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }
}

private enum ChipGuide: String, Identifiable {
    case usageCount
    case strokes
    case structure
    case radical

    var id: String { rawValue }

    func description(for item: ComponentItem) -> String {
        switch self {
        case .usageCount:
            if item.usageCount <= 1 {
                return "Not present in other characters."
            }
            return "Present in \(item.usageCount) characters."
        case .strokes:
            return "Number of strokes."
        case .structure:
            return "How the character is built from components."
        case .radical:
            return "Dictionary indexing radical."
        }
    }
}
