import Foundation
#if canImport(UIKit)
import UIKit
#endif

enum RadixInterfaceIdiom {
    case desktop
    case tablet
    case phone

    var isPhone: Bool { self == .phone }
    var isDesktop: Bool { self == .desktop }

    var searchResultColumnCount: Int { isDesktop ? 15 : 8 }
    var searchResultFontSize: CGFloat { isDesktop ? 28 : 24 }
    var searchResultRowHeight: CGFloat { isDesktop ? 56 : 52 }

    var phraseRowHeight: CGFloat {
        switch self {
        case .desktop: return 84
        case .tablet: return 82
        case .phone: return 72
        }
    }

    var phraseLeadingColumnWidth: CGFloat {
        switch self {
        case .desktop: return 150
        case .tablet: return 120
        case .phone: return 96
        }
    }

    var phraseTileHeight: CGFloat { self == .phone ? 54 : 58 }

    func usesNarrowLayout(horizontalIsCompact: Bool) -> Bool {
        !isDesktop && (isPhone || horizontalIsCompact)
    }
}

struct RadixPlatform {
    @MainActor static var interfaceIdiom: RadixInterfaceIdiom {
        #if targetEnvironment(macCatalyst)
        return .desktop
        #elseif canImport(UIKit)
        return UIDevice.current.userInterfaceIdiom == .pad ? .tablet : .phone
        #else
        return .tablet
        #endif
    }

    @MainActor static var isPhone: Bool {
        interfaceIdiom.isPhone
    }

    @MainActor static var isDesktop: Bool {
        interfaceIdiom.isDesktop
    }

    @MainActor static var isRunningOnMac: Bool {
        #if targetEnvironment(macCatalyst)
        return true
        #elseif canImport(UIKit)
        if #available(iOS 14.0, *) {
            return ProcessInfo.processInfo.isiOSAppOnMac
        }
        return false
        #else
        return false
        #endif
    }

    @MainActor static func copyToPasteboard(_ text: String) {
        #if canImport(UIKit)
        UIPasteboard.general.string = text
        #endif
    }

    @MainActor static func copyImageToPasteboard(_ jpegData: Data) {
        #if canImport(UIKit)
        guard let image = UIImage(data: jpegData) else { return }
        UIPasteboard.general.image = image
        #endif
    }

    @MainActor static func pasteboardImage() throws -> CapturedImage? {
        #if canImport(UIKit)
        guard let image = UIPasteboard.general.image else { return nil }
        return try CapturedImage(image: image)
        #else
        return nil
        #endif
    }

    @MainActor static var pasteboardString: String {
        #if canImport(UIKit)
        return UIPasteboard.general.string ?? ""
        #else
        return ""
        #endif
    }

    @MainActor static func open(_ url: URL, after delay: TimeInterval = 0) {
        #if canImport(UIKit)
        DispatchQueue.main.asyncAfter(deadline: .now() + delay) {
            UIApplication.shared.open(url)
        }
        #endif
    }
}
