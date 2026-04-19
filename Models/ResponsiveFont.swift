import SwiftUI

public struct ResponsiveFont {
    #if targetEnvironment(macCatalyst)
    public static let title = Font.system(size: 44, weight: .bold)
    public static let title2 = Font.system(size: 38, weight: .bold)
    public static let title3 = Font.system(size: 32, weight: .bold)
    public static let headline = Font.system(size: 28, weight: .bold)
    public static let subheadline = Font.system(size: 24, weight: .semibold)
    public static let body = Font.system(size: 24)
    public static let callout = Font.system(size: 22)
    public static let footnote = Font.system(size: 20)
    public static let caption = Font.system(size: 18)
    public static let caption2 = Font.system(size: 16)
    #else
    public static let title = Font.title
    public static let title2 = Font.title2
    public static let title3 = Font.title3
    public static let headline = Font.headline
    public static let subheadline = Font.subheadline
    public static let body = Font.body
    public static let callout = Font.callout
    public static let footnote = Font.footnote
    public static let caption = Font.caption
    public static let caption2 = Font.caption2
    #endif
}
