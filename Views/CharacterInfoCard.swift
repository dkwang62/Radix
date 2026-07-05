import SwiftUI

struct CharacterInfoCard: View {
    @EnvironmentObject var store: RadixStore
    let item: ComponentItem
    let variants: [String]
    let onSelectVariant: ((String) -> Void)?
    let showClearButton: Bool
    let onShowPhrases: (() -> Void)?
    let onClear: (() -> Void)?
    @State var showFrequencyGuide = false
    @State var activeChipGuide: ChipGuide?
    @State var showComponentsPopover = false
    @State var showSentenceExampleSheet = false
    @State var selectedPopupComponent: String?
    @Binding var variantIndex: Int

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

    init(item: ComponentItem, counterpart: String?, onSelectCounterpart: ((String) -> Void)? = nil) {
        self.item = item
        self.variants = counterpart.map { [$0] } ?? []
        self._variantIndex = .constant(0)
        self.showClearButton = false
        self.onShowPhrases = nil
        self.onClear = nil
        self.onSelectVariant = onSelectCounterpart
    }

    var isPhone: Bool {
        RadixPlatform.isPhone
    }

    var body: some View {
        standardContent
            .padding(16)
            .background(RadixTheme.background)
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(RadixTheme.separator, lineWidth: 1)
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
            .sheet(isPresented: $showSentenceExampleSheet) {
                SentenceExampleListSheet(
                    title: "Examples",
                    examples: SentenceExampleDisplayRules.examples(containingCharacter: item.character, limit: nil)
                )
                .environmentObject(store)
            }
    }

    var standardContent: some View {
        VStack(alignment: .leading, spacing: 12) {
            headerRow(
                characterSize: isPhone ? 30 : 34,
                pinyinFont: isPhone ? .system(size: 32, weight: .bold) : .system(size: 34, weight: .bold)
            )

            actionRow
            referenceMetaRow
            componentIconStrip
            definitionAndNotes
        }
    }

    var actionRow: some View {
        CharacterInfoCardActions(
            character: item.character,
            showClearButton: showClearButton,
            isPhone: isPhone,
            onShowPhrases: onShowPhrases,
            onShowExamples: { showSentenceExampleSheet = true },
            onClear: onClear
        )
    }
}
