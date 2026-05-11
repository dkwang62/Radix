import SwiftUI
#if canImport(UIKit)
import UIKit
#endif

struct FavouritesTab: View {
    static let addedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    @EnvironmentObject var store: RadixStore
    @EnvironmentObject var entitlement: EntitlementManager
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void
    @State var selectedPhrase: PhraseItem?

    var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            favouritesHeader

            if store.favoriteItems.isEmpty && store.favoritePhrasesItems.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Tap the star icon on any character or phrase to add it to this list."))
            } else {
                favouritesScrollContent
            }
        }
        .sheet(item: phonePhraseSheetBinding) { phrase in
            NavigationStack {
                PhraseInfoCard(phrase: phrase, onDone: {
                    selectedPhrase = nil
                    })
                    .environmentObject(store)
                    .padding()
                    .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .large])
        }
    }
}
