import Foundation
import SwiftUI

/// Browse-grid and component-explorer filter selections.
struct RadixBrowseFilterState {
    var favoritesOnly = false
    var minimumStroke = 0
    var maximumStroke = 30
    var radical = "none"
    var structure = "none"
    var rootMinimumStroke = 0
    var rootMaximumStroke = 30
    var rootRadical = "none"
    var rootStructure = "none"
    var gridSortMode: GridSortMode = .characterFrequency
    var gridScriptFilter: ScriptFilter = .any
}

extension RadixStore {
    var favoritesOnlyFilter: Bool {
        get { browseFilterState.favoritesOnly }
        set { browseFilterState.favoritesOnly = newValue }
    }

    var strokeMinFilter: Int {
        get { browseFilterState.minimumStroke }
        set {
            guard browseFilterState.minimumStroke != newValue else { return }
            browseFilterState.minimumStroke = newValue
            resetGridAfterFilterChange()
        }
    }

    var strokeMaxFilter: Int {
        get { browseFilterState.maximumStroke }
        set {
            let pinnedValue = 30
            guard browseFilterState.maximumStroke != pinnedValue || newValue != pinnedValue else { return }
            browseFilterState.maximumStroke = pinnedValue
            resetGridAfterFilterChange()
        }
    }

    var selectedRadicalFilter: String {
        get { browseFilterState.radical }
        set {
            guard browseFilterState.radical != newValue else { return }
            browseFilterState.radical = newValue
            resetGridAfterFilterChange()
        }
    }

    var selectedStructureFilter: String {
        get { browseFilterState.structure }
        set {
            guard browseFilterState.structure != newValue else { return }
            browseFilterState.structure = newValue
            resetGridAfterFilterChange()
        }
    }

    var rootMinStroke: Int {
        get { browseFilterState.rootMinimumStroke }
        set {
            guard browseFilterState.rootMinimumStroke != newValue else { return }
            browseFilterState.rootMinimumStroke = newValue
            reloadRootContextForFilterChange()
        }
    }

    var rootMaxStroke: Int {
        get { browseFilterState.rootMaximumStroke }
        set {
            let clampedValue = min(max(newValue, 0), 30)
            guard browseFilterState.rootMaximumStroke != clampedValue || newValue != clampedValue else { return }
            browseFilterState.rootMaximumStroke = clampedValue
            reloadRootContextForFilterChange()
        }
    }

    var rootRadicalFilter: String {
        get { browseFilterState.rootRadical }
        set {
            guard browseFilterState.rootRadical != newValue else { return }
            browseFilterState.rootRadical = newValue
            reloadRootContextForFilterChange()
        }
    }

    var rootStructureFilter: String {
        get { browseFilterState.rootStructure }
        set {
            guard browseFilterState.rootStructure != newValue else { return }
            browseFilterState.rootStructure = newValue
            reloadRootContextForFilterChange()
        }
    }

    var gridSortMode: GridSortMode {
        get { browseFilterState.gridSortMode }
        set {
            guard browseFilterState.gridSortMode != newValue else { return }
            browseFilterState.gridSortMode = newValue
            resetGridAfterFilterChange()
        }
    }

    var gridScriptFilter: ScriptFilter {
        get { browseFilterState.gridScriptFilter }
        set {
            guard browseFilterState.gridScriptFilter != newValue else { return }
            browseFilterState.gridScriptFilter = newValue
            resetGridAfterFilterChange()
        }
    }

    func browseFilterBinding<Value>(_ keyPath: ReferenceWritableKeyPath<RadixStore, Value>) -> Binding<Value> {
        Binding(
            get: { self[keyPath: keyPath] },
            set: { self[keyPath: keyPath] = $0 }
        )
    }

    private func resetGridAfterFilterChange() {
        gridPage = 0
        scheduleGridRecompute()
    }

    private func reloadRootContextForFilterChange() {
        guard let current = previewCharacter else { return }
        loadSharedComponentPeers(for: current)
        loadSharedPeersByComponent(for: current)
        loadRootDerivatives(for: current)
    }
}
