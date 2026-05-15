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

    var hasStudyContent: Bool {
        !store.rootBreadcrumb.isEmpty
            || !store.favoriteItems.isEmpty
            || !store.favoritePhrasesItems.isEmpty
            || !store.allCollections.isEmpty
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            favouritesHeader

            if isPhoneStudyPreviewActive {
                ScrollView {
                    phoneStudyPreview
                        .padding(.horizontal)
                        .padding(.bottom, 20)
                }
            } else if hasStudyContent {
                favouritesScrollContent
            } else {
                ContentUnavailableView("No Study Items", systemImage: "clock.badge.questionmark", description: Text("Search, scan, or star a character."))
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

    var isPhoneStudyPreviewActive: Bool {
        isPhone && (store.previewCharacter != nil || store.activeSidebarPhrasePreview != nil)
    }

    var phoneStudyPreview: some View {
        PhoneContextPreview(
            returnTitle: "Study",
            returnSystemImage: "star",
            phrase: store.activeSidebarPhrasePreview,
            character: store.previewCharacter,
            onReturn: {
                selectedPhrase = nil
                store.dismissSidebarPhrasePreview()
                store.previewCharacter = nil
            }
        )
        .environmentObject(store)
    }
}
