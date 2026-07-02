import SwiftUI

struct BrowsePhonePreview: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem?
    let character: String?
    let pageReturnTitle: String?
    let onReturn: () -> Void

    var body: some View {
        PhoneContextPreview(
            phrase: phrase,
            character: character,
            listReturnTitle: pageReturnTitle,
            onReturn: onReturn
        )
        .environmentObject(store)
    }
}
