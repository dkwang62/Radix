import SwiftUI

extension CharacterDetailView {
    var lineageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            lineageControls

            if !store.lineageParents.isEmpty {
                lineageStrip(title: "Breakdown (How it's built)", items: store.lineageParents)
            }

            lineageStrip(title: "Derivatives", items: store.pagedLineageDerivatives)

            if entitlement.requiresPro(.lineage) && store.sortedLineageDerivatives.count > 20 {
                Button {
                    store.showPaywall(for: .lineage)
                } label: {
                    HStack {
                        Image(systemName: "lock.fill")
                        Text("Show all \(store.sortedLineageDerivatives.count) derivatives")
                    }
                    .font(ResponsiveFont.subheadline.bold())
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.accentColor.opacity(0.1))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }

    func lineageCell(_ linkedItem: ComponentItem, fontSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            VStack(spacing: 2) {
                Text(linkedItem.character)
                    .font(.system(size: fontSize))
                    .copyCharacterContextMenu(linkedItem.character, pinyin: linkedItem.pinyinText)
                Text(linkedItem.pinyinText.isEmpty ? " " : linkedItem.pinyinText)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .foregroundStyle(Color.primary)

            if linkedItem.usageCount > 0 {
                Text("\(linkedItem.usageCount.formatted(.number.grouping(.never)))")
                    .font(.system(size: 13, weight: .black))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 2)
                    .background(Color.secondary.opacity(0.15))
                    .foregroundStyle(.secondary)
            }
        }
        .background(Color.secondary.opacity(0.1))
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(Color.secondary.opacity(0.2), lineWidth: 0.5)
        )
        .contentShape(RoundedRectangle(cornerRadius: 8))
        .onTapGesture {
            store.showComponentHelp = false
            store.preview(character: linkedItem.character)
        }
    }

    func lineageStrip(title: String, items: [ComponentItem]) -> some View {
        let columns: [GridItem] = {
            #if targetEnvironment(macCatalyst)
            return Array(repeating: GridItem(.flexible(), spacing: 6), count: 15)
            #else
            return Array(repeating: GridItem(.flexible(), spacing: 6), count: 8)
            #endif
        }()

        let fontSize: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 48
            #else
            return 24
            #endif
        }()

        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title.replacingOccurrences(of: " (How it's built)", with: ""))
                    .font(ResponsiveFont.headline)
                    .foregroundStyle(.secondary)
                Spacer()
                if title.contains("Breakdown") {
                    Button {
                        store.showComponentHelp = false
                    } label: {
                        Label("Explore Breakdown", systemImage: "point.3.connected.trianglepath.dotted")
                            .font(ResponsiveFont.subheadline)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(sizeClass == .compact ? .small : .regular)
                }
            }

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(items, id: \.character) { linkedItem in
                    lineageCell(linkedItem, fontSize: fontSize)
                }
            }
        }
        .padding(.vertical, 4)
    }

    var lineageControls: some View {
        HStack {
            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }

            Spacer(minLength: 8)

            Button {
                store.previousLineagePage()
            } label: {
                Image(systemName: "chevron.left")
                    .frame(width: 32, height: 30)
            }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.lineagePage == 0)

            Text("\(store.lineagePage + 1) / \(store.lineagePageCount)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .monospacedDigit()
                .frame(minWidth: 52)

            Button {
                store.nextLineagePage()
            } label: {
                Image(systemName: "chevron.right")
                    .frame(width: 32, height: 30)
            }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .disabled(store.lineagePage + 1 >= store.lineagePageCount)
        }
        .padding(10)
        .background(RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
