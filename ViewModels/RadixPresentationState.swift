import Foundation
import SwiftUI

/// Transient presentation, help, and launch-request state shared by app shells.
struct RadixPresentationState {
    var showsPaywall = false
    var paywallFeatureName = "Pro Feature"
    var shouldCloseBrowsePages = false
    var shouldOpenAddedPhraseReview = false
    var shouldStartBrowseCamera = false
    var activeFavouriteCharacter: String?
    var quickEditDestination: QuickEditDestination?
    var showsPhoneDetail = false
    var showsBrowseHelp = true
    var showsComponentHelp = true
    var activeCaptureDraft = CaptureDraft()
}

extension RadixStore {
    var showPaywall: Bool { get { presentationState.showsPaywall } set { presentationState.showsPaywall = newValue } }
    var paywallFeatureName: String { get { presentationState.paywallFeatureName } set { presentationState.paywallFeatureName = newValue } }
    var shouldCloseBrowsePages: Bool { get { presentationState.shouldCloseBrowsePages } set { presentationState.shouldCloseBrowsePages = newValue } }
    var shouldOpenAddedPhraseReview: Bool { get { presentationState.shouldOpenAddedPhraseReview } set { presentationState.shouldOpenAddedPhraseReview = newValue } }
    var shouldStartBrowseCamera: Bool { get { presentationState.shouldStartBrowseCamera } set { presentationState.shouldStartBrowseCamera = newValue } }
    var activeFavouriteCharacter: String? { get { presentationState.activeFavouriteCharacter } set { presentationState.activeFavouriteCharacter = newValue } }
    var quickEditDestination: QuickEditDestination? { get { presentationState.quickEditDestination } set { presentationState.quickEditDestination = newValue } }
    var showiPhoneDetail: Bool { get { presentationState.showsPhoneDetail } set { presentationState.showsPhoneDetail = newValue } }
    var showBrowseHelp: Bool { get { presentationState.showsBrowseHelp } set { presentationState.showsBrowseHelp = newValue } }
    var showComponentHelp: Bool { get { presentationState.showsComponentHelp } set { presentationState.showsComponentHelp = newValue } }
    var activeCaptureDraft: CaptureDraft { get { presentationState.activeCaptureDraft } set { presentationState.activeCaptureDraft = newValue } }

    func presentationBinding<Value>(_ keyPath: ReferenceWritableKeyPath<RadixStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}
