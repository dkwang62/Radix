import SwiftUI

struct BrowsePhonePreview: View {
    @EnvironmentObject private var store: RadixStore
    let phrase: PhraseItem?
    let character: String?
    let onReturn: () -> Void

    var body: some View {
        PhoneContextPreview(
            returnTitle: "Browse",
            returnSystemImage: "square.grid.2x2",
            phrase: phrase,
            character: character,
            onReturn: onReturn
        )
        .environmentObject(store)
    }
}
