import Foundation
import SwiftUI

/// Transient presentation, help, and launch-request state shared by app shells.
struct RadixPresentationState {
    var showsPaywall = false
    var paywallFeatureName = "Pro Feature"
    var shouldCloseBrowseSource = false
    var shouldOpenAddedPhraseReview = false
    var shouldOpenCaptureCamera = false
    var shouldOpenCaptureTextPage = false
    var shouldOpenCaptureClipboardImage = false
    var shouldOpenCaptureAlbum = false
    var shouldOpenCaptureFiles = false
    var activeFavouriteCharacter: String?
    var quickEditDestination: QuickEditDestination?
    var showsPhoneDetail = false
    var showsBrowseHelp = true
    var showsComponentHelp = true
    var showsLatestAIResult = false
    var activeCaptureDraft = CaptureDraft()
    var sharedImportFailure: RadixSharedImportFailure?
}

extension RadixStore {
    var showPaywall: Bool { get { presentationState.showsPaywall } set { presentationState.showsPaywall = newValue } }
    var paywallFeatureName: String { get { presentationState.paywallFeatureName } set { presentationState.paywallFeatureName = newValue } }
    var shouldCloseBrowseSource: Bool { get { presentationState.shouldCloseBrowseSource } set { presentationState.shouldCloseBrowseSource = newValue } }
    var shouldOpenAddedPhraseReview: Bool { get { presentationState.shouldOpenAddedPhraseReview } set { presentationState.shouldOpenAddedPhraseReview = newValue } }
    var shouldOpenCaptureCamera: Bool { get { presentationState.shouldOpenCaptureCamera } set { presentationState.shouldOpenCaptureCamera = newValue } }
    var shouldOpenCaptureTextPage: Bool { get { presentationState.shouldOpenCaptureTextPage } set { presentationState.shouldOpenCaptureTextPage = newValue } }
    var shouldOpenCaptureClipboardImage: Bool { get { presentationState.shouldOpenCaptureClipboardImage } set { presentationState.shouldOpenCaptureClipboardImage = newValue } }
    var shouldOpenCaptureAlbum: Bool { get { presentationState.shouldOpenCaptureAlbum } set { presentationState.shouldOpenCaptureAlbum = newValue } }
    var shouldOpenCaptureFiles: Bool { get { presentationState.shouldOpenCaptureFiles } set { presentationState.shouldOpenCaptureFiles = newValue } }
    var activeFavouriteCharacter: String? { get { presentationState.activeFavouriteCharacter } set { presentationState.activeFavouriteCharacter = newValue } }
    var quickEditDestination: QuickEditDestination? { get { presentationState.quickEditDestination } set { presentationState.quickEditDestination = newValue } }
    var showiPhoneDetail: Bool { get { presentationState.showsPhoneDetail } set { presentationState.showsPhoneDetail = newValue } }
    var showBrowseHelp: Bool { get { presentationState.showsBrowseHelp } set { presentationState.showsBrowseHelp = newValue } }
    var showComponentHelp: Bool { get { presentationState.showsComponentHelp } set { presentationState.showsComponentHelp = newValue } }
    var showLatestAIResult: Bool { get { presentationState.showsLatestAIResult } set { presentationState.showsLatestAIResult = newValue } }
    var activeCaptureDraft: CaptureDraft { get { presentationState.activeCaptureDraft } set { presentationState.activeCaptureDraft = newValue } }
    var sharedImportFailure: RadixSharedImportFailure? { get { presentationState.sharedImportFailure } set { presentationState.sharedImportFailure = newValue } }

    func presentationBinding<Value>(_ keyPath: ReferenceWritableKeyPath<RadixStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }
}
