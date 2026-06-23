import Foundation

/// Transient presentation, help, and launch-request state shared by app shells.
struct RadixPresentationState {
    var showsPaywall = false
    var paywallFeatureName = "Pro Feature"
    var shouldOpenBrowsePages = false
    var shouldOpenAddedPhraseReview = false
    var shouldStartBrowseCamera = false
    var activeFavouriteCharacter: String?
    var quickEditDestination: QuickEditDestination?
    var showsPhoneDetail = false
    var showsBrowseHelp = true
    var showsComponentHelp = true
    var activeCaptureDraft = CaptureDraft()
}
