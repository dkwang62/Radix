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
    @State private var showComponentsPopover = false
    @State private var selectedPopupComponent: String?
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
            selectedPopupComponent = nil
        }
        .popover(isPresented: $showComponentsPopover, arrowEdge: .bottom) {
            ComponentsRootsPopover(
                character: item.character,
                selectedComponent: $selectedPopupComponent
            )
            .environmentObject(store)
            .applyComponentsRootsPopoverStyle()
        }
    }

    private var content: some View {
        standardContent
    }

    private var standardContent: some View {
        VStack(alignment: .leading, spacing: 10) {
            headerRow(
                characterSize: isPhone ? 30 : 34,
                pinyinFont: isPhone ? .system(size: 32, weight: .bold) : .system(size: 34, weight: .bold)
            )

            tierRow

            if !structurePartsText.isEmpty || !item.radical.isEmpty {
                HStack(spacing: 6) {
                    if !structurePartsText.isEmpty {
                        chipButton(structurePartsText, guide: .structure)
                    }
                }
            }

            componentIconStrip

            if let strokes = item.strokes {
                HStack(spacing: 6) {
                    strokeCountButton(strokes)
                }
            }

            actionRow

            definitionAndNotes
        }
    }

    private var actionRow: some View {
        CharacterInfoCardActions(
            character: item.character,
            showClearButton: showClearButton,
            isPhone: isPhone,
            onShowPhrases: onShowPhrases,
            onClear: onClear
        )
    }

    private var tierRow: some View {
        HStack(spacing: 6) {
            tierButton
            Spacer(minLength: 0)
        }
    }

    private func headerRow(
        characterSize: CGFloat,
        pinyinFont: Font
    ) -> some View {
        HStack(alignment: .top, spacing: 8) {
            usageCharactersButton(characterSize: characterSize)

            Text(displayPinyin)
                .font(pinyinFont)
                .foregroundStyle(Color.orange)
                .lineLimit(2)
                .fixedSize(horizontal: false, vertical: true)
                .minimumScaleFactor(0.7)
                .layoutPriority(1)

            Spacer(minLength: 0)
            favoritesButton
        }
    }

    private var favoritesButton: some View {
        Button {
            store.setFavorite(character: item.character, isFavorite: !store.isFavorite(item.character))
        } label: {
            Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
                .foregroundStyle(store.isFavorite(item.character) ? .yellow : .secondary)
        }
        .buttonStyle(.plain)
        .controlSize(cardActionControlSize)
        .font(cardActionFont)
        .help(store.isFavorite(item.character) ? "Remove from favorites" : "Add to favorites")
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

    private func strokeCountButton(_ strokes: Int) -> some View {
        Button {
            activeChipGuide = .strokes
        } label: {
            HStack(spacing: 6) {
                Text("✍️ Strokes:")
                    .font(cardActionFont)
                Text("\(strokes)")
                    .font(cardActionFont)
            }
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .padding(.horizontal, 10)
            .padding(.vertical, 7)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(Color(.separator), lineWidth: 0.5)
            )
        }
        .buttonStyle(.plain)
        .popover(isPresented: chipGuideBinding(for: .strokes), arrowEdge: .bottom) {
            chipGuideView(for: .strokes)
                .applyCompactPopoverStyle()
        }
    }

    private func usageCharactersButton(characterSize: CGFloat) -> some View {
        Button {
            guard item.usageCount > 1 else {
                activeChipGuide = .usageCount
                return
            }
            openComponentsPopover(component: item.character)
        } label: {
            characterTile(
                character: item.character,
                subtitle: usageCountSubtitle,
                size: characterTileSize,
                characterSize: characterSize,
                isHighlighted: false
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
        .popover(isPresented: chipGuideBinding(for: .usageCount), arrowEdge: .bottom) {
            chipGuideView(for: .usageCount)
                .applyCompactPopoverStyle()
        }
    }

    private func openComponentsPopover(component: String?) {
        selectedPopupComponent = component ?? item.character
        showComponentsPopover = true
    }

    private var cardComponents: [ComponentItem] {
        store.components(for: item.character)
    }

    @ViewBuilder
    private var componentIconStrip: some View {
        if !cardComponents.isEmpty {
            LazyVGrid(columns: componentGridColumns, alignment: .leading, spacing: 8) {
                ForEach(cardComponents, id: \.character) { component in
                    componentIconButton(component)
                }
            }
        }
    }

    @ViewBuilder
    private func componentIconButton(_ component: ComponentItem) -> some View {
        let isRadical = component.character == item.radical
        Button {
            openComponentsPopover(component: component.character)
        } label: {
            characterTile(
                character: component.character,
                subtitle: component.pinyinText.isEmpty ? nil : component.pinyinText,
                size: componentTileSize,
                characterSize: componentCharacterFontSize,
                isHighlighted: isRadical
            )
        }
        .buttonStyle(.plain)
        .copyCharacterContextMenu(component.character, pinyin: component.pinyinText)
    }

    private func characterTile(
        character: String,
        subtitle: String?,
        size: CGFloat,
        characterSize: CGFloat,
        isHighlighted: Bool
    ) -> some View {
        VStack(spacing: 2) {
            Text(character)
                .font(.system(size: characterSize, weight: .bold))
                .foregroundStyle(Color.accentColor)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
            if let subtitle {
                Text(subtitle)
                    .font(ResponsiveFont.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .frame(width: size, height: size)
        .background(isHighlighted ? Color.orange.opacity(0.18) : Color(.secondarySystemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHighlighted ? Color.orange.opacity(0.75) : Color(.separator), lineWidth: isHighlighted ? 1.5 : 0.5)
        )
    }

    private var componentGridColumns: [GridItem] {
        [GridItem(.adaptive(minimum: componentTileSize, maximum: componentTileSize), spacing: 6)]
    }

    private var characterTileSize: CGFloat {
        isPhone ? 64 : 70
    }

    private var componentTileSize: CGFloat {
        isPhone ? 48 : 54
    }

    private var componentCharacterFontSize: CGFloat {
        isPhone ? 20 : 22
    }

    private var usageCountSubtitle: String {
        "\(item.usageCount)"
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
            
            guideRow(tier: "Tier 1", label: "Core Literacy", desc: "Everyday survival. Essential for everyone.")
            guideRow(tier: "Tier 2", label: "Fluency Core", desc: "Reading newspapers,  media")
            guideRow(tier: "Tier 3", label: "Educated Native", desc: "University-level reading, formal writing")
            guideRow(tier: "Tier 4", label: "Academic", desc: "Specialized, technical, research-heavy")
            guideRow(tier: "Tier 5", label: "Niche/Rare", desc: "Rare names, dialect, archaic forms")
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
        case 1: return "Core Literacy"
        case 2: return "Fluency Core"
        case 3: return "Educated Native"
        case 4: return "Academic/Pro"
        default: return "Niche/Rare"
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
            .font(ResponsiveFont.caption.weight(.bold))
            .foregroundStyle(.white)
            .lineLimit(1)
            .minimumScaleFactor(0.8)
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(tierColor)
            .clipShape(RoundedRectangle(cornerRadius: 8))
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
        return ResponsiveFont.caption2.weight(.semibold)
        #else
        return ResponsiveFont.caption.weight(.semibold)
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

    private var chipNumberFont: Font {
        #if targetEnvironment(macCatalyst)
        return ResponsiveFont.subheadline.weight(.bold)
        #else
        return isPhone ? ResponsiveFont.title3.weight(.bold) : ResponsiveFont.subheadline.weight(.bold)
        #endif
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
