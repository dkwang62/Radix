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
    @Environment(\.horizontalSizeClass) var horizontalSizeClass
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void
    @State var selectedPhrase: PhraseItem?
    @AppStorage("studyGridUsesTraditionalScript") var studyGridUsesTraditionalScript = false
    @AppStorage("studyGridScope") var studyGridScopeRawValue = StudyGridScope.all.rawValue
    @AppStorage("studyPageSortOrder") var studyPageSortRawValue = PageCollectionSortOrder.lastViewed.rawValue
    @AppStorage("hasDismissedStudyIntroV1") var hasDismissedStudyIntro = false

    var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var isNarrowStudyLayout: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return isPhone || horizontalSizeClass == .compact
        #endif
    }

    var hasStudyContent: Bool {
        store.recentCharacterCount > 0
            || store.rootBreadcrumb.contains { $0.count > 1 }
            || !store.favoriteItems.isEmpty
            || !store.favoritePhrasesItems.isEmpty
            || !store.allCollections.isEmpty
    }

    var studyPageSortOrder: PageCollectionSortOrder {
        get { PageCollectionSortOrder(rawValue: studyPageSortRawValue) ?? .lastViewed }
        nonmutating set { studyPageSortRawValue = newValue.rawValue }
    }

    var studyGridScope: StudyGridScope {
        get { StudyGridScope(rawValue: studyGridScopeRawValue) ?? .all }
        nonmutating set { studyGridScopeRawValue = newValue.rawValue }
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
            returnSystemImage: RadixIcon.study,
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

enum StudyGridScope: String, CaseIterable, Identifiable {
    case all = "All"
    case favorites = "Saved"

    var id: String { rawValue }

    var title: String {
        switch self {
        case .all: return "All"
        case .favorites: return "Favorites"
        }
    }
}
