import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

@MainActor
func presentShareSheet(items: [Any]) {
    #if canImport(UIKit)
    guard let presenter = UIApplication.shared.radixTopMostViewController else { return }
    let controller = UIActivityViewController(activityItems: items, applicationActivities: nil)
    controller.popoverPresentationController?.sourceView = presenter.view
    controller.popoverPresentationController?.sourceRect = CGRect(
        x: presenter.view.bounds.midX,
        y: presenter.view.bounds.midY,
        width: 1,
        height: 1
    )
    presenter.present(controller, animated: true)
    #elseif canImport(AppKit)
    guard let window = NSApplication.shared.keyWindow,
          let view = window.contentView else { return }
    let picker = NSSharingServicePicker(items: items)
    picker.show(relativeTo: view.bounds, of: view, preferredEdge: .minY)
    #endif
}

#if canImport(UIKit)
private extension UIApplication {
    var radixTopMostViewController: UIViewController? {
        connectedScenes
            .compactMap { $0 as? UIWindowScene }
            .flatMap(\.windows)
            .first { $0.isKeyWindow }?
            .rootViewController?
            .radixTopMostPresentedViewController
    }
}

private extension UIViewController {
    var radixTopMostPresentedViewController: UIViewController {
        if let presentedViewController {
            return presentedViewController.radixTopMostPresentedViewController
        }
        if let navigationController = self as? UINavigationController {
            return navigationController.visibleViewController?.radixTopMostPresentedViewController ?? navigationController
        }
        if let tabBarController = self as? UITabBarController {
            return tabBarController.selectedViewController?.radixTopMostPresentedViewController ?? tabBarController
        }
        return self
    }
}
#endif
