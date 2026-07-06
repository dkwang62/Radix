import SwiftUI

extension ComponentsExplorerShell {
    var derivativesSection: some View {
        VStack(alignment: .leading, spacing: derivativesExpanded ? 8 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    derivativesExpanded.toggle()
                }
            } label: {
                RadixChevronRow(
                    icon: "character",
                    title: "Characters containing \(seed) (\(store.rootDerivativesTotal))",
                    subtitle: derivativesExpanded ? "Sorted by popular usage." : nil,
                    minHeight: 48,
                    titleFont: ResponsiveFont.headline,
                    chevronSystemName: derivativesExpanded ? "chevron.up" : "chevron.down"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if derivativesExpanded {
                if store.rootDerivatives.isEmpty {
                    Text("No derivatives found for this character.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                } else {
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 8) {
                            ForEach(store.rootDerivatives, id: \.character) { item in
                                branchRow(item)
                            }
                        }
                    }
                }
            }
        }
        .padding(10)
        .radixSurface(RadixTheme.secondaryBackground, radius: 10)
    }

    @ViewBuilder
    var sharedPeersSections: some View {
        if !store.sharedPeersByComponent.isEmpty {
            ForEach(Array(store.sharedPeersByComponent.keys).sorted(), id: \.self) { comp in
                sharedPeersSection(for: comp)
            }
        }
    }

    func sharedPeersSection(for comp: String) -> some View {
        let compItem = store.item(for: comp)
        let peers = store.sharedPeersByComponent[comp] ?? []
        let rowItems: [ComponentItem] = {
            guard let compItem else { return peers }
            return ([compItem] + peers).reduce(into: []) { partial, item in
                if !partial.contains(where: { $0.character == item.character }) {
                    partial.append(item)
                }
            }
        }()
        let isExpanded = expandedComponents.contains(comp)

        return VStack(alignment: .leading, spacing: isExpanded ? 8 : 0) {
            Button {
                withAnimation(.easeInOut(duration: 0.2)) {
                    if isExpanded {
                        expandedComponents.remove(comp)
                    } else {
                        expandedComponents.insert(comp)
                    }
                }
            } label: {
                RadixChevronRow(
                    icon: "square.grid.2x2",
                    title: componentSectionTitle(for: comp, item: compItem) + " (\(rowItems.count))",
                    subtitle: isExpanded ? "Sorted by component frequency." : nil,
                    minHeight: 48,
                    titleFont: ResponsiveFont.headline,
                    chevronSystemName: isExpanded ? "chevron.up" : "chevron.down"
                )
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if isExpanded {
                sharedPeersGrid(rowItems)
            }
        }
        .padding(10)
        .radixSurface(RadixTheme.secondaryBackground, radius: 10)
    }

    @ViewBuilder
    func sharedPeersGrid(_ rowItems: [ComponentItem]) -> some View {
        #if targetEnvironment(macCatalyst)
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: 8)], spacing: 8) {
            ForEach(rowItems, id: \.character) { item in
                branchRow(item)
            }
        }
        #else
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(rowItems, id: \.character) { item in
                    branchRow(item)
                }
            }
        }
        #endif
    }

    func initialRootGrid(items: [ComponentItem], total: Int) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text("All characters (\(total))")
                    .font(ResponsiveFont.headline)
                Text("Choose a character.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            if items.isEmpty {
                Text("No matches.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                LazyVGrid(columns: [GridItem(.adaptive(minimum: 72, maximum: 120), spacing: 8)], spacing: 8) {
                    ForEach(items, id: \.character) { item in
                        initialRootCell(item)
                    }
                }
            }
        }
    }

    func initialRootCell(_ item: ComponentItem) -> some View {
        VStack(spacing: 4) {
            Text(item.character)
                .font(.system(size: 30, weight: .bold))
            Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                .font(ResponsiveFont.caption)
                .fontWeight(.semibold)
                .foregroundStyle(.secondary)
            Text("\(item.usageCount)")
                .font(ResponsiveFont.caption2)
                .fontWeight(.semibold)
                .foregroundStyle(.tertiary)
        }
        .padding(8)
        .radixSurface(RadixTheme.background, border: RadixTheme.separator, borderWidth: 0.5)
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            startRootExploration(with: item.character, remember: false)
        }
        .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
    }

    func branchRow(_ item: ComponentItem) -> some View {
        ComponentCharacterTile(item: item) {
            pivot(to: item.character, selectAfter: false)
        }
    }

    func componentSectionTitle(for component: String, item: ComponentItem?) -> String {
        let trimmed = component.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "Characters containing this component" }
        return "Characters containing \(item?.character ?? trimmed)"
    }
}
