import SwiftUI

enum PageWorkspaceMode: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case study = "Study"

    var id: String { rawValue }
}

private enum SavedPageHeaderDateFormatter {
    static let scan: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.dateFormat = "dd MMM yy"
        return formatter
    }()
}

struct SavedPageWorkspaceHeader<PageSelector: View>: View {
    let collection: CharacterCollection
    let isActive: Bool
    let dateMode: PageCollectionSortOrder
    let pageSelector: PageSelector

    init(
        collection: CharacterCollection,
        isActive: Bool,
        dateMode: PageCollectionSortOrder,
        @ViewBuilder pageSelector: () -> PageSelector
    ) {
        self.collection = collection
        self.isActive = isActive
        self.dateMode = dateMode
        self.pageSelector = pageSelector()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            pageSelector
                .layoutPriority(1)

            Spacer(minLength: 4)

            Text(scanText)
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(isActive ? RadixAccent.primary : Color.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
                .radixPill(
                    horizontal: 6,
                    vertical: 4,
                    background: (isActive ? RadixAccent.primary : Color.secondary).opacity(0.10),
                    radius: 7
                )

        }
        .frame(minHeight: 44)
    }

    private var scanText: String {
        let date = switch dateMode {
        case .lastViewed:
            collection.lastViewedAt ?? collection.createdAt
        case .scanned:
            collection.createdAt
        }
        return SavedPageHeaderDateFormatter.scan.string(from: date)
    }
}

struct PageSelectionSwitcher: View {
    let pages: [CharacterCollection]
    let selectedPageID: UUID?
    let displayName: (CharacterCollection) -> String
    let onSelect: (CharacterCollection) -> Void
    var sortOrder: Binding<PageCollectionSortOrder>? = nil
    var labelTitle = "Switch"
    var labelFont = ResponsiveFont.caption2.weight(.semibold)
    var labelForegroundStyle: Color = .primary
    var labelMinWidth: CGFloat? = 54

    var body: some View {
        Menu {
            if let sortOrder {
                Section("Sort Pages") {
                    ForEach(PageCollectionSortOrder.allCases) { order in
                        Button {
                            sortOrder.wrappedValue = order
                        } label: {
                            Label(
                                order.rawValue,
                                systemImage: sortOrder.wrappedValue == order ? "checkmark" : "calendar"
                            )
                        }
                    }
                }
            }

            ForEach(pages) { page in
                Button {
                    onSelect(page)
                } label: {
                    Label(
                        displayName(page),
                        systemImage: page.id == selectedPageID ? "checkmark" : "doc.text"
                    )
                }
            }
        } label: {
            RadixCompactChevronLabel(
                title: labelTitle,
                font: labelFont,
                chevronFont: ResponsiveFont.tinySystem(size: 9, weight: .bold),
                minWidth: labelMinWidth
            )
            .foregroundStyle(labelForegroundStyle)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Switch page")
        .accessibilityValue(
            pages.first(where: { $0.id == selectedPageID }).map(displayName) ?? "No page selected"
        )
    }
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
        .frame(width: 132)
        .accessibilityLabel("Switch page workspace")
        .accessibilityValue("Currently \(selectedMode.rawValue)")
    }
}
