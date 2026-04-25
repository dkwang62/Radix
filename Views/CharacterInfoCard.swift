import SwiftUI

struct CharacterInfoCard: View {
    @EnvironmentObject private var store: RadixStore
    let item: ComponentItem
    let variants: [String]
    let onSelectVariant: ((String) -> Void)?
    @State private var showFrequencyGuide = false
    @State private var showTierGuideMobile = false
    @Binding var variantIndex: Int

    private let idcChars: Set<Character> = ["⿰", "⿱", "⿲", "⿳", "⿴", "⿵", "⿶", "⿷", "⿸", "⿹", "⿺", "⿻"]

    init(item: ComponentItem, variants: [String], variantIndex: Binding<Int>, onSelectVariant: ((String) -> Void)? = nil) {
        self.item = item
        self.variants = variants
        self._variantIndex = variantIndex
        self.onSelectVariant = onSelectVariant
    }

    // Backwards-compat init for call sites still passing a single counterpart
    init(item: ComponentItem, counterpart: String?, onSelectCounterpart: ((String) -> Void)? = nil) {
        self.item = item
        self.variants = counterpart.map { [$0] } ?? []
        self._variantIndex = .constant(0)
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
        VStack(alignment: .leading, spacing: 12) {
            // Row 1: Character + Pinyin + favorite
            HStack(alignment: .top, spacing: 8) {
                Text(item.character)
                    .font(.system(size: isPhone ? 34 : 40, weight: .bold))
                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)

                if let variant = currentVariant, !variant.isEmpty {
                    variantButton(for: variant)
                }

                Text(displayPinyin)
                    .font(ResponsiveFont.title.bold())
                    .foregroundStyle(Color.orange)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.7)
                    .layoutPriority(1)

                Spacer(minLength: 4)

                Button {
                    store.setFavorite(character: item.character, isFavorite: !store.isFavorite(item.character))
                } label: {
                    Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
                        .font(.system(size: 18, weight: .semibold))
                        .foregroundStyle(store.isFavorite(item.character) ? .yellow : .secondary)
                        .padding(8)
                        .background(Color.accentColor.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
            }

            // Tier sits directly under the headline on wider layouts.
            if !isPhone {
                HStack(alignment: .center, spacing: 8) {
                    tierButton
                    Spacer(minLength: 0)
                }
            }

            // Usage, strokes, and radical share one row.
            HStack(spacing: 6) {
                chip("In \(item.usageCount) chars")
                if let strokes = item.strokes {
                    chip("\(strokes) strokes")
                }
                if !item.radical.isEmpty {
                    chip("Rad. \(item.radical)")
                }
                if isPhone {
                    Button {
                        showTierGuideMobile = true
                    } label: {
                        tierChip(for: item.tier)
                    }
                    .buttonStyle(.plain)
                    .popover(isPresented: $showTierGuideMobile, arrowEdge: .bottom) {
                        tierGuideView
                            .padding()
                    }
                }
            }

            // Row 4: Structure Info
            if !structurePartsText.isEmpty {
                chip(structurePartsText)
            }

            // Row 6: Definition
            Text(item.definition.isEmpty ? "No definition" : item.definition)
                .font(ResponsiveFont.subheadline)
                .foregroundStyle(.primary)

            // Row 7: Etymology (Optional)
            if !etymologyText.isEmpty {
                Divider()
                Text(etymologyText)
                    .font(ResponsiveFont.footnote)
                    .italic()
                    .foregroundStyle(.secondary)
            }

            if !notesText.isEmpty {
                Divider()
                VStack(alignment: .leading, spacing: 6) {
                    Label("Notes", systemImage: "note.text")
                        .font(ResponsiveFont.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    Text(notesText)
                        .font(ResponsiveFont.footnote)
                        .foregroundStyle(.primary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
        }
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

    private func variantButton(for variant: String) -> some View {
        Button {
            if variants.count > 1 {
                variantIndex = (variantIndex + 1) % variants.count
            } else {
                onSelectVariant?(variant)
            }
        } label: {
            Text(variant)
                .font(.system(size: isPhone ? 34 : 40, weight: .bold))
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .copyCharacterContextMenu(variant, pinyin: store.item(for: variant)?.pinyinText)
                .padding(.horizontal, 2)
            .foregroundStyle(Color.accentColor)
        }
        .buttonStyle(.plain)
        .help(variants.count > 1 ? "Cycle variants" : "Open variant")
        .accessibilityLabel(variants.count > 1 ? "Cycle variant \(variant)" : "Open variant \(variant)")
        .contextMenu {
            ForEach(variants, id: \.self) { v in
                Button {
                    onSelectVariant?(v)
                } label: {
                    let pinyin = store.item(for: v)?.pinyinText ?? ""
                    Label("\(v)  \(pinyin)", systemImage: "arrow.right.circle")
                }
            }
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

    private var displayPinyin: String {
        let joined = item.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        return joined.isEmpty ? "—" : joined
    }

    private var partsText: String {
        let parts = item.decomposition
            .filter { !idcChars.contains($0) }
            .map(String.init)
            .filter { !$0.isEmpty && $0 != "?" && $0 != "—" && $0 != item.character }
        return parts.prefix(4).joined(separator: " ")
    }

    private var structurePartsText: String {
        let parts = partsText
        if let symbol = structureSymbol, !parts.isEmpty {
            return "Structure \(symbol) · \(parts)"
        }
        if let symbol = structureSymbol {
            return "Structure \(symbol)"
        }
        return parts
    }

    private var structureSymbol: String? {
        guard let first = item.decomposition.first, idcChars.contains(first) else { return nil }
        return String(first)
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
            .font(ResponsiveFont.footnote.weight(.semibold))
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
