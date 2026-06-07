import SwiftUI

extension SmartSearchTab {
    var isPhone: Bool {
        RadixPlatform.isPhone
    }

    @ViewBuilder
    var phoneSearchPreviewIfNeeded: some View {
        if RadixPlatform.isPhone,
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
    }

    var isPhoneSearchPreviewActive: Bool {
        guard RadixPlatform.isPhone else { return false }
        return store.activeSidebarPhrasePreview != nil || searchDetailPreviewCharacter != nil || searchPreviewCharacter != nil
    }

    @ViewBuilder
    func phoneSearchPreview(proxy: ScrollViewProxy) -> some View {
        PhoneContextPreview(
            returnTitle: "Search",
            returnSystemImage: "magnifyingglass",
            phrase: store.activeSidebarPhrasePreview,
            character: searchDetailPreviewCharacter ?? searchPreviewCharacter ?? store.previewCharacter,
            onReturn: {
                selectedPhrase = nil
                store.dismissSidebarPhrasePreview()
                searchPreviewCharacter = nil
                searchDetailPreviewCharacter = nil
                store.previewCharacter = nil
                withAnimation(.easeInOut(duration: 0.2)) {
                    proxy.scrollTo("searchTop", anchor: .top)
                }
            }
        )
        .environmentObject(store)
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
            get: { nil },
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
                selectedPhrase = nil
            } else {
                selectedPhrase = nil
                store.presentPhraseInSidebar(phrase)
            }
        }
    }
}
