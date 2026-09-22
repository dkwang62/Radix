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

struct SavedPageWorkspaceHeader<Accessory: View>: View {
    let collection: CharacterCollection
    let displayName: String
    let isActive: Bool
    let accessory: Accessory

    init(
        collection: CharacterCollection,
        displayName: String,
        isActive: Bool,
        @ViewBuilder accessory: () -> Accessory
    ) {
        self.collection = collection
        self.displayName = displayName
        self.isActive = isActive
        self.accessory = accessory()
    }

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            Text(displayName)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? RadixAccent.primary : Color.primary)
                .lineLimit(1)
                .layoutPriority(1)

            accessory

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
        SavedPageHeaderDateFormatter.scan.string(from: collection.createdAt)
    }
}

extension SavedPageWorkspaceHeader where Accessory == EmptyView {
    init(collection: CharacterCollection, displayName: String, isActive: Bool) {
        self.init(
            collection: collection,
            displayName: displayName,
            isActive: isActive,
            accessory: { EmptyView() }
        )
    }
}

struct PageSelectionSwitcher: View {
    let pages: [CharacterCollection]
    let selectedPageID: UUID?
    let displayName: (CharacterCollection) -> String
    let onSelect: (CharacterCollection) -> Void
    var sortOrder: Binding<PageCollectionSortOrder>? = nil

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
                title: "Switch",
                chevronFont: ResponsiveFont.tinySystem(size: 9, weight: .bold),
                minWidth: 54
            )
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
        let destination = selectedMode == .browse ? PageWorkspaceMode.study : .browse
        Button(destination.rawValue) {
            onSelect(destination)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Switch page workspace")
        .accessibilityValue("Currently \(selectedMode.rawValue)")
        .accessibilityHint("Opens \(destination.rawValue)")
    }
}
