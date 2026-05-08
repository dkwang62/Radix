import SwiftUI
import UIKit

enum BrowseGridDeviceClass {
    case mac
    case iPad
    case iPhone

    @MainActor static var current: BrowseGridDeviceClass {
        #if targetEnvironment(macCatalyst)
        return .mac
        #else
        return UIDevice.current.userInterfaceIdiom == .pad ? .iPad : .iPhone
        #endif
    }
}

struct BrowseGridLayout {
    let deviceClass: BrowseGridDeviceClass

    @MainActor static var current: BrowseGridLayout {
        BrowseGridLayout(deviceClass: .current)
    }

    var dictionaryColumns: Int {
        switch deviceClass {
        case .mac:
            return 15
        case .iPad, .iPhone:
            return 8
        }
    }

    var dictionaryRows: Int {
        switch deviceClass {
        case .mac:
            return 10
        case .iPad:
            return 14
        case .iPhone:
            return 8
        }
    }

    var dictionaryPageSize: Int {
        dictionaryColumns * dictionaryRows
    }

    var tileMinimumWidth: CGFloat {
        deviceClass == .mac ? 40 : 32
    }

    var tileMaximumWidth: CGFloat {
        deviceClass == .mac ? 80 : 64
    }

    var characterFontSize: CGFloat {
        deviceClass == .mac ? 28 : 24
    }

    var gridColumns: [GridItem] {
        Array(
            repeating: GridItem(.flexible(minimum: tileMinimumWidth, maximum: tileMaximumWidth), spacing: 0),
            count: dictionaryColumns
        )
    }
}

struct BrowseScrollTarget: Equatable {
    let collectionID: UUID?
    let character: String?
    let offset: Int?
}
