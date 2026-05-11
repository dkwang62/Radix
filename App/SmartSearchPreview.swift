import SwiftUI

extension SmartSearchTab {
    var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    @ViewBuilder
    var phoneSearchPreviewIfNeeded: some View {
        #if !targetEnvironment(macCatalyst)
        if UIDevice.current.userInterfaceIdiom == .phone,
           let current = searchDetailPreviewCharacter ?? searchPreviewCharacter,
           store.item(for: current) != nil {
            standardPhoneCharacterPreview(
                character: current,
                onClear: {
                    searchPreviewCharacter = nil
                    searchDetailPreviewCharacter = nil
                    store.previewCharacter = nil
                }
            )
        }
        #endif
    }

    func syncSearchPreviewFromStore() {
        guard store.hasPerformedSearch, searchPreviewCharacter == nil else { return }
        searchDetailPreviewCharacter = store.previewCharacter
    }

    func finishPhraseLookup() {
        selectedPhrase = nil
        store.dismissSidebarPhrasePreview()
    }

    var phonePhraseSheetBinding: Binding<PhraseItem?> {
        Binding(
            get: { isPhone ? selectedPhrase : nil },
            set: { newValue in
                if isPhone {
                    selectedPhrase = newValue
                }
            }
        )
    }

    func presentPhrase(_ phrase: PhraseItem) {
        store.speakPhrase(phrase)
        withAnimation(.easeInOut(duration: 0.2)) {
            if isPhone {
                store.presentPhraseInSidebar(phrase)
                selectedPhrase = phrase
            } else {
                selectedPhrase = nil
                store.presentPhraseInSidebar(phrase)
            }
        }
    }
}
