import SwiftUI

struct CharacterDetailView: View {
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @Environment(\.horizontalSizeClass) var sizeClass
    let item: ComponentItem
    @State private var showPhraseTable = false

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if sizeClass == .compact {
                        header
                    }

                    if sizeClass != .compact {
                        HStack(spacing: 8) {
                            editCharacterButton
                            phraseTableButton {
                                withAnimation(.easeInOut(duration: 0.2)) {
                                    showPhraseTable.toggle()
                                }
                                if showPhraseTable {
                                    store.refreshPhrases()
                                    DispatchQueue.main.async {
                                        withAnimation(.easeInOut(duration: 0.2)) {
                                            proxy.scrollTo("phraseTableSection", anchor: .top)
                                        }
                                    }
                                }
                            }
                            rootsButton
                        }
                    }

                    // Quick explainer for how to use Components Explorer
                    if store.showComponentHelp {
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Components Explorer")
                                .font(ResponsiveFont.subheadline.bold())
                            Text("Link characters through a shared component: start from a familiar character, tap a component to pivot, view characters built with that part, and keep pivoting until you find the one you need.")
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                            Text("Tap any character to preview. Numbers in boxes show how many characters contain that part.")
                                .font(ResponsiveFont.caption)
                                .foregroundStyle(.secondary)
                        }
                        .padding(.vertical, 4)
                    }

                    lineageSection
                    if sizeClass != .compact && showPhraseTable {
                        CharacterPhraseLookupSection {
                            withAnimation(.easeInOut(duration: 0.2)) {
                                showPhraseTable = false
                            }
                        }
                            .id("phraseTableSection")
                    }
                }
                .padding(20)
            }
        }
        .navigationTitle("")
        .toolbar {
            Button {
                store.toggleFavorite(character: item.character)
            } label: {
                Image(systemName: store.isFavorite(item.character) ? "star.fill" : "star")
            }
        }
        .onChange(of: store.phraseLength) { _, _ in
            store.refreshPhrases()
        }
        .onChange(of: store.previewCharacter) { _, _ in
            store.refreshPhrases()
        }
        .onAppear { store.refreshPhrases() }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 12) {
            if sizeClass == .compact {
                compactHeader
            } else {
                regularHeader
            }
        }
    }

    /// iPhone / compact split-view header: animated stroke order + info card.
    private var compactHeader: some View {
        CharacterPreviewHeader(
            character: item.character,
            showClearButton: false,
            isVertical: true
        )
        .padding(.bottom, 8)
    }

    /// iPad / Mac regular header: large static character + pinyin + definition + variant buttons.
    private var regularHeader: some View {
        HStack(alignment: .top, spacing: 16) {
            Text(item.character)
                .font(.system(size: 112))
                .lineLimit(1)
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)

            VStack(alignment: .leading, spacing: 8) {
                Text(item.pinyinText.isEmpty ? "No pinyin" : item.pinyinText)
                    .font(ResponsiveFont.title2)
                    .foregroundStyle(.secondary)
                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(ResponsiveFont.title3)
                let allVariants = store.allVariants(for: item.character)
                if !allVariants.isEmpty {
                    HStack(spacing: 8) {
                        ForEach(allVariants, id: \.character) { v in
                            Button {
                                store.select(character: v.character)
                                store.preview(character: v.character)
                            } label: {
                                Text("Variant: \(v.character)")
                                    .font(ResponsiveFont.subheadline)
                            }
                            .buttonStyle(.bordered)
                        }
                    }
                }
            }
            Spacer(minLength: 0)
        }
    }

    private var lineageSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            lineageControls
            VStack(alignment: .leading, spacing: 6) {
                // Instruction lines now consolidated above; keep this space minimal.
            }
            .font(ResponsiveFont.subheadline) // Increased from caption2
            .foregroundStyle(.tertiary)

            if !store.lineageParents.isEmpty {
                lineageStrip(title: "Components (How it's built)", items: store.lineageParents)
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
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
            }
        }
    }

    private func lineageCell(_ linkedItem: ComponentItem, fontSize: CGFloat) -> some View {
        VStack(spacing: 0) {
            // Character + pinyin
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

            // Usage footer
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

    private func lineageStrip(title: String, items: [ComponentItem]) -> some View {
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
                if title.contains("Components") {
                    Button {
                        store.showComponentHelp = false
                    } label: {
                        Label("Components Explorer", systemImage: "point.3.connected.trianglepath.dotted")
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

    private var lineageControls: some View {
        HStack {
            CompactScriptFilterControl(selection: store.scriptFilter) { store.setScriptFilter($0) }

            Spacer(minLength: 8)

            Button("Prev") { store.previousLineagePage() }
                .font(ResponsiveFont.subheadline)
                .buttonStyle(.bordered)
                .disabled(store.lineagePage == 0)
            Text("Batch \(store.lineagePage + 1)/\(store.lineagePageCount)")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Button("Next") { store.nextLineagePage() }
                .font(ResponsiveFont.subheadline)
                .buttonStyle(.bordered)
                .disabled(store.lineagePage + 1 >= store.lineagePageCount)
        }
    }

    private func phraseTableButton(action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 8) {
                Image(systemName: showPhraseTable ? "text.justify" : "text.justify.left")
                Text(showPhraseTable ? "Hide Phrase Table" : "Show Phrase Table")
                Spacer()
                Text("\(store.phraseLength)-char")
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .font(ResponsiveFont.subheadline.weight(.semibold))
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
            .background(Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var editCharacterButton: some View {
        Button {
            store.openQuickCharacterEditor(item.character)
        } label: {
            Label("Notes", systemImage: "square.and.pencil")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

    private var rootsButton: some View {
        Button {
            store.goToRoots(character: item.character)
        } label: {
            Label("Components", systemImage: "tree")
                .font(ResponsiveFont.caption.weight(.semibold))
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(Color(.secondarySystemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }

}
