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
