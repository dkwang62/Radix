import SwiftUI

enum PageWorkspaceMode: String, CaseIterable, Identifiable {
    case browse = "Browse"
    case study = "Study"

    var id: String { rawValue }
}

struct SavedPageWorkspaceHeader: View {
    let collection: CharacterCollection
    let displayName: String
    let isActive: Bool

    var body: some View {
        HStack(alignment: .center, spacing: 10) {
            RadixPageIconView(
                size: 34,
                cornerRadius: 8,
                systemImage: collection.isFavorite ? "star.fill" : "photo",
                color: collection.isFavorite ? Color.yellow : Color.secondary
            )

            Text(displayName)
                .font(ResponsiveFont.subheadline.weight(.semibold))
                .foregroundStyle(isActive ? RadixAccent.primary : Color.primary)
                .lineLimit(1)
                .layoutPriority(1)

            Spacer(minLength: 6)

            Label(scanText, systemImage: "calendar")
                .font(ResponsiveFont.caption2.weight(.semibold))
                .foregroundStyle(isActive ? RadixAccent.primary : Color.secondary)
                .labelStyle(.titleAndIcon)
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
        "Scanned \(collection.createdAt.formatted(date: .abbreviated, time: .omitted))"
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
                title: "Switch Page",
                systemImage: "rectangle.stack",
                chevronFont: ResponsiveFont.tinySystem(size: 9, weight: .bold),
                minWidth: 104
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
