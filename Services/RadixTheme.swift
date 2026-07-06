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

/// Brand color aliases. Keep the current app accent as the primary identity;
/// do not override it from code so the asset catalog remains the source of
/// truth for Radix's teal/green visual language.
enum RadixAccent {
    static var primary: Color { Color.accentColor }
    static var success: Color { Color.green }
    static var onPrimary: Color { Color.white }
}

/// Shared glyph sizes for small symbolic controls. Use these for recurring
/// icons so equivalent controls do not drift by a point or two per screen.
enum RadixIconSize {
    static let small: CGFloat = 12
    static let standard: CGFloat = 15
    static let large: CGFloat = 18
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

private struct RadixPillModifier: ViewModifier {
    let horizontal: CGFloat
    let vertical: CGFloat
    let background: Color
    let border: Color?
    let borderWidth: CGFloat
    let radius: CGFloat

    func body(content: Content) -> some View {
        content
            .padding(.horizontal, horizontal)
            .padding(.vertical, vertical)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(border, lineWidth: borderWidth)
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

    func radixPill(
        horizontal: CGFloat = RadixSpacing.small,
        vertical: CGFloat = RadixSpacing.xSmall,
        background: Color = RadixTheme.secondaryBackground,
        border: Color? = nil,
        borderWidth: CGFloat = 1,
        radius: CGFloat = RadixRadius.medium
    ) -> some View {
        modifier(RadixPillModifier(
            horizontal: horizontal,
            vertical: vertical,
            background: background,
            border: border,
            borderWidth: borderWidth,
            radius: radius
        ))
    }

    /// Applies the shared surface vocabulary when padding/frame order must stay
    /// local to the caller. Prefer `radixCard` or `radixPill` when possible.
    func radixSurface(
        _ background: Color,
        radius: CGFloat = RadixRadius.medium,
        border: Color? = nil,
        borderWidth: CGFloat = 1
    ) -> some View {
        self
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .overlay {
                if let border {
                    RoundedRectangle(cornerRadius: radius)
                        .stroke(border, lineWidth: borderWidth)
                }
            }
    }

    /// Keeps compact icon controls visually small while preserving Apple's
    /// recommended minimum interactive area for touch and pointer users.
    func radixMinimumTapTarget() -> some View {
        frame(
            minWidth: RadixControlMetrics.standardHeight,
            minHeight: RadixControlMetrics.standardHeight
        )
        .contentShape(Rectangle())
    }

    func radixIconButtonSurface(
        size: CGFloat = RadixControlMetrics.standardHeight,
        background: Color = RadixTheme.secondaryBackground,
        radius: CGFloat = RadixRadius.medium
    ) -> some View {
        frame(width: size, height: size)
            .background(background)
            .clipShape(RoundedRectangle(cornerRadius: radius))
            .contentShape(RoundedRectangle(cornerRadius: radius))
    }
}

enum RadixHaptics {
    @MainActor
    static func light() {
        #if canImport(UIKit) && !os(watchOS)
        UIImpactFeedbackGenerator(style: .light).impactOccurred()
        #endif
    }

    @MainActor
    static func success() {
        #if canImport(UIKit) && !os(watchOS)
        UINotificationFeedbackGenerator().notificationOccurred(.success)
        #endif
    }

    @MainActor
    static func error() {
        #if canImport(UIKit) && !os(watchOS)
        UINotificationFeedbackGenerator().notificationOccurred(.error)
        #endif
    }

    @MainActor
    static func selectionChanged() {
        #if canImport(UIKit) && !os(watchOS)
        UISelectionFeedbackGenerator().selectionChanged()
        #endif
    }
}

#if DEBUG
private struct RadixDesignSystemPreview: View {
    var body: some View {
        VStack(alignment: .leading, spacing: RadixSpacing.large) {
            Text("Visual System")
                .font(.title.bold())

            VStack(alignment: .leading, spacing: RadixSpacing.small) {
                RadixTermLabel(term: RadixTerm.savedPage)
                    .font(.headline)
                Text("Cards, controls, and explanatory text should retain the same hierarchy at every text size.")
                    .font(.body)
                    .foregroundStyle(.secondary)
            }
            .radixCard()

            HStack(spacing: RadixSpacing.small) {
                Text("Pill")
                    .font(.caption.weight(.semibold))
                    .radixPill(background: RadixAccent.primary.opacity(0.12))
                    .foregroundStyle(RadixAccent.primary)
                Button("Primary") { }
                    .buttonStyle(.borderedProminent)
                    .radixMinimumTapTarget()
                Button("Secondary") { }
                    .buttonStyle(.bordered)
                    .radixMinimumTapTarget()
                Button("Delete", role: .destructive) { }
                    .buttonStyle(.bordered)
                    .radixMinimumTapTarget()
            }
        }
        .padding(RadixSpacing.large)
        .frame(maxWidth: 560, alignment: .leading)
        .background(RadixTheme.groupedBackground)
    }
}

private struct RadixDesignSystemPreviewProvider: PreviewProvider {
    static var previews: some View {
        Group {
            RadixDesignSystemPreview()
                .previewDisplayName("Default")
            RadixDesignSystemPreview()
                .environment(\.dynamicTypeSize, .accessibility3)
                .previewDisplayName("Accessibility Text")
            RadixDesignSystemPreview()
                .preferredColorScheme(.dark)
                .previewDisplayName("Dark")
        }
    }
}
#endif
