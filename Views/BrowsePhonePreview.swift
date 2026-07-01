import SwiftUI

struct BrowsePhonePreview: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem?
    let character: String?
    let onReturn: () -> Void

    var body: some View {
        PhoneContextPreview(
            phrase: phrase,
            character: character,
            onReturn: onReturn
        )
        .environmentObject(store)
    }
}
