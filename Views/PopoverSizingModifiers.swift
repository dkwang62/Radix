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
    func applyComponentsRootsPopoverStyle() -> some View {
        if #available(iOS 16.4, macCatalyst 16.4, *) {
            if RadixPlatform.isPhone {
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
    }

}
