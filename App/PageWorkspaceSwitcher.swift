import SwiftUI

enum PageWorkspaceMode: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case study = "Study"

    var id: String { rawValue }
}

struct PageWorkspaceSwitcher: View {
    let selectedMode: PageWorkspaceMode
    let onSelect: (PageWorkspaceMode) -> Void

    var body: some View {
        Picker("Page workspace", selection: Binding(
            get: { selectedMode },
            set: { mode in
                guard mode != selectedMode else { return }
                onSelect(mode)
            }
        )) {
            ForEach(PageWorkspaceMode.allCases) { mode in
                Text(mode.rawValue).tag(mode)
            }
        }
        .pickerStyle(.segmented)
        .frame(width: 170)
        .accessibilityLabel("Page workspace")
        .accessibilityValue(selectedMode.rawValue)
    }
}
