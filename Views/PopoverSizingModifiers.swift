import SwiftUI

extension View {
    @ViewBuilder
    func applyCompactPopoverStyle() -> some View {
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
    }

    @ViewBuilder
    func applyReadablePopoverStyle() -> some View {
        #if targetEnvironment(macCatalyst)
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
        #else
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            if UIDevice.current.userInterfaceIdiom == .phone {
                self
                    .presentationCompactAdaptation(.sheet)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
            } else {
                self.presentationCompactAdaptation(.popover)
            }
        } else {
            self
        }
        #endif
    }

    @ViewBuilder
    func applyComponentsRootsPopoverStyle() -> some View {
        #if targetEnvironment(macCatalyst)
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            self.presentationCompactAdaptation(.popover)
        } else {
            self
        }
        #else
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            if UIDevice.current.userInterfaceIdiom == .phone {
                self
                    .presentationCompactAdaptation(.sheet)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            } else {
                self.presentationCompactAdaptation(.popover)
            }
        } else {
            self
        }
        #endif
    }

    @ViewBuilder
    func applyFittedSheetSizing() -> some View {
        if #available(iOS 18.0, macCatalyst 18.0, *) {
            self.presentationSizing(.fitted)
        } else {
            self
        }
    }
}
