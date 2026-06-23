import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

enum RadixTheme {
    static var background: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color.white
        #endif
    }

    static var secondaryBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .secondarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .controlBackgroundColor)
        #else
        Color(red: 0.95, green: 0.95, blue: 0.96)
        #endif
    }

    static var tertiaryBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .tertiarySystemBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .underPageBackgroundColor)
        #else
        Color(red: 0.90, green: 0.90, blue: 0.92)
        #endif
    }

    static var groupedBackground: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGroupedBackground)
        #elseif canImport(AppKit)
        Color(nsColor: .windowBackgroundColor)
        #else
        Color(red: 0.94, green: 0.94, blue: 0.96)
        #endif
    }

    static var separator: Color {
        #if canImport(UIKit)
        Color(uiColor: .separator)
        #elseif canImport(AppKit)
        Color(nsColor: .separatorColor)
        #else
        Color.secondary.opacity(0.35)
        #endif
    }

    static var systemGray5: Color {
        #if canImport(UIKit)
        Color(uiColor: .systemGray5)
        #elseif canImport(AppKit)
        Color(nsColor: .quaternaryLabelColor)
        #else
        Color.secondary.opacity(0.18)
        #endif
    }
}

/// Shared visual measurements. Feature views should use these instead of
/// introducing one-off spacing, radius, and control-height values.
enum RadixSpacing {
    static let xSmall: CGFloat = 4
    static let small: CGFloat = 8
    static let medium: CGFloat = 12
    static let large: CGFloat = 16
    static let xLarge: CGFloat = 24
}

enum RadixRadius {
    static let small: CGFloat = 6
    static let medium: CGFloat = 8
    static let large: CGFloat = 12
    static let modal: CGFloat = 16
}

enum RadixControlMetrics {
    static let compactHeight: CGFloat = 34
    static let standardHeight: CGFloat = 44
    static let prominentHeight: CGFloat = 58
    static let actionCardHeight: CGFloat = 72
}

enum RadixLayoutMetrics {
    static let readableContentWidth: CGFloat = 900
    static let compactCardPadding: CGFloat = 10
    static let cardPadding: CGFloat = 12
}

private struct RadixCardModifier: ViewModifier {
    let padding: CGFloat
    let background: Color
    let border: Color?
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(padding)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(border, lineWidth: 1)
                }
            }
    }
}

extension View {
    func radixCard(
        padding: CGFloat = RadixLayoutMetrics.cardPadding,
        background: Color = RadixTheme.secondaryBackground,
        border: Color? = nil,
        radius: CGFloat = RadixRadius.medium
    ) -> some View {
        modifier(RadixCardModifier(
            padding: padding,
            background: background,
            border: border,
            radius: radius
        ))
    }
}
