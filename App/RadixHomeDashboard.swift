import SwiftUI

struct RadixHomeDashboard: View {
    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    @State private var commandText = ""
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    private var recentItems: [String] {
        Array(store.rootBreadcrumb.prefix(10))
    }

    private var recentPages: [CharacterCollection] {
        Array(store.allCollections.prefix(4))
    }

    private var savedThingCount: Int {
        store.favoriteItems.count + store.favoritePhrasesItems.count + store.allCollections.count + store.addedPhrases.count + store.changedDictionaryCharacters.count
    }

    private var customDataCount: Int {
        store.addedPhrases.count + store.changedDictionaryCharacters.count
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 18) {
                hero
                commandBar
                continueSection
                actionGrid
                companionStats
                portabilityPanel
                recentPagesSection
            }
            .padding(.horizontal)
            .padding(.bottom, 24)
        }
        .background(Color(.systemGroupedBackground))
    }

    private var hero: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .top, spacing: 14) {
                Image(systemName: "character.book.closed")
                    .font(.system(size: 30, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 54, height: 54)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 5) {
                    Text("Your lifelong Chinese companion")
                        .font(ResponsiveFont.title2.bold())
                        .fixedSize(horizontal: false, vertical: true)
                    Text("Radix keeps the Chinese you meet in real life: scan it, understand it, save it, study it, and carry your data across iPhone, iPad, and Mac.")
                        .font(ResponsiveFont.body)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                homeChip("Scan")
                homeChip("Understand")
                homeChip("Save")
                homeChip("Study")
                homeChip("Move My Data")
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var commandBar: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(spacing: 10) {
                Image(systemName: "sparkle.magnifyingglass")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 38, height: 38)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 2) {
                    Text("Ask Radix")
                        .font(ResponsiveFont.headline)
                    Text("Type a character, phrase, or action like scan, study, AI, or My Data.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            HStack(spacing: 8) {
                TextField("Character, phrase, or action", text: $commandText)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .submitLabel(.go)
                    .onSubmit(runCommand)
                    .padding(.horizontal, 12)
                    .frame(minHeight: 42)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .overlay(
                        RoundedRectangle(cornerRadius: 8)
                            .stroke(Color(.separator), lineWidth: 0.5)
                    )

                Button(action: runCommand) {
                    Image(systemName: "arrow.right")
                        .font(.system(size: 17, weight: .bold))
                        .frame(width: 42, height: 42)
                }
                .buttonStyle(.borderedProminent)
                .disabled(commandText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 8) {
                    commandSuggestion("Scan a page")
                    commandSuggestion("Browse dictionary")
                    commandSuggestion("Study saved")
                    commandSuggestion("AI Link")
                    commandSuggestion("Move My Data")
                }
                .padding(.trailing, 8)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var continueSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            sectionHeader("Continue")

            if recentItems.isEmpty {
                homeEmptyRow(
                    icon: "camera.viewfinder",
                    title: "Start with real Chinese text",
                    text: "Scan a page, paste text, or browse the dictionary."
                ) {
                    store.route = .capture
                }
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 8) {
                        ForEach(Array(recentItems.enumerated()), id: \.offset) { _, item in
                            recentItemButton(item)
                        }
                    }
                    .padding(.vertical, 2)
                    .padding(.trailing, 8)
                }
            }
        }
    }

    private var actionGrid: some View {
        LazyVGrid(columns: actionColumns, spacing: 10) {
            homeAction(
                title: "Scan",
                text: "Capture Chinese from a photo, file, camera, or pasted text.",
                icon: "camera.viewfinder",
                tint: .blue
            ) {
                store.route = .capture
            }

            homeAction(
                title: "Browse",
                text: "Explore the dictionary, saved pages, parts, variants, and phrases.",
                icon: "square.grid.2x2",
                tint: .teal
            ) {
                store.goToBrowse()
            }

            homeAction(
                title: "Search",
                text: "Find by Chinese, pinyin, English meaning, or strokes.",
                icon: "magnifyingglass",
                tint: .indigo
            ) {
                store.goToSearchRoot()
            }

            homeAction(
                title: "Study",
                text: "Return to favorites, remembered items, and saved pages.",
                icon: "star",
                tint: .yellow
            ) {
                store.goToFavourites()
            }

            homeAction(
                title: "AI Link",
                text: "Use repeatable AI actions for phrases, translation, and interpretation.",
                icon: "sparkles",
                tint: .purple
            ) {
                store.enterAILink()
            }

            homeAction(
                title: "My Data",
                text: "Review what you added and move it between your devices.",
                icon: "externaldrive",
                tint: .green
            ) {
                store.goToDataEdit()
            }
        }
    }

    private var companionStats: some View {
        LazyVGrid(columns: statColumns, spacing: 8) {
            statTile("Saved", "\(savedThingCount)", "heart.text.square", .pink)
            statTile("Characters", "\(store.favoriteItems.count)", "character", .orange)
            statTile("Phrases", "\(store.favoritePhrasesItems.count)", "text.quote", .green)
            statTile("Pages", "\(store.allCollections.count)", "photo.on.rectangle", .purple)
        }
    }

    private var portabilityPanel: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "iphone.and.arrow.forward")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))

                VStack(alignment: .leading, spacing: 3) {
                    Text("Your Radix data should travel with you")
                        .font(ResponsiveFont.headline)
                    Text("What you add on iPhone can move to iPad and Mac with My Backup.")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer(minLength: 0)
            }

            HStack(spacing: 8) {
                Label("\(customDataCount) personal items", systemImage: "tray.full")
                    .font(ResponsiveFont.caption.bold())
                    .foregroundStyle(.secondary)
                Spacer(minLength: 0)
                Button {
                    if entitlement.requiresPro(.myBackup) {
                        onRequirePro(.myBackup)
                    } else {
                        store.goToDataEdit()
                    }
                } label: {
                    Label(entitlement.requiresPro(.myBackup) ? "Unlock My Backup" : "Open My Data", systemImage: "arrow.right")
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.small)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    @ViewBuilder
    private var recentPagesSection: some View {
        if !recentPages.isEmpty {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    sectionHeader("Recent Pages")
                    Spacer()
                    Button {
                        store.goToBrowse()
                    } label: {
                        Label("Browse", systemImage: "square.grid.2x2")
                            .font(ResponsiveFont.caption.bold())
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                }

                LazyVGrid(columns: pageColumns, spacing: 8) {
                    ForEach(recentPages) { collection in
                        pageButton(collection)
                    }
                }
            }
        }
    }

    private var actionColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 190), spacing: 10), count: 3)
        #else
        return Array(repeating: GridItem(.flexible(minimum: 150), spacing: 10), count: 2)
        #endif
    }

    private var statColumns: [GridItem] {
        Array(repeating: GridItem(.flexible(minimum: 120), spacing: 8), count: 2)
    }

    private var pageColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 160), spacing: 8), count: 4)
        #else
        return Array(repeating: GridItem(.flexible(minimum: 140), spacing: 8), count: 2)
        #endif
    }

    private func sectionHeader(_ text: String) -> some View {
        Text(text)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(.secondary)
    }

    private func homeChip(_ text: String) -> some View {
        Text(text)
            .font(ResponsiveFont.caption.bold())
            .foregroundStyle(Color.accentColor)
            .padding(.horizontal, 9)
            .padding(.vertical, 5)
            .background(Color.accentColor.opacity(0.1))
            .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func commandSuggestion(_ text: String) -> some View {
        Button {
            commandText = text
            runCommand()
        } label: {
            Text(text)
                .font(ResponsiveFont.caption.bold())
                .foregroundStyle(.primary)
                .padding(.horizontal, 10)
                .padding(.vertical, 7)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func runCommand() {
        let raw = commandText.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !raw.isEmpty else { return }
        let command = raw.lowercased()
        commandText = ""

        if command.contains("scan") || command.contains("camera") || command.contains("photo") || command.contains("image") || command.contains("ocr") {
            store.route = .capture
            return
        }

        if command.contains("browse") || command.contains("dictionary") || command.contains("grid") {
            store.goToBrowse()
            return
        }

        if command.contains("study") || command.contains("saved") || command.contains("favorite") || command.contains("favourite") || command.contains("remember") {
            store.goToFavourites()
            return
        }

        if command.contains("ai") || command.contains("translate") || command.contains("interpret") || command.contains("extract") || command.contains("template") {
            store.enterAILink()
            return
        }

        if command.contains("data") || command.contains("backup") || command.contains("move") || command.contains("iphone") || command.contains("ipad") || command.contains("mac") || command.contains("portable") {
            store.goToDataEdit()
            return
        }

        if raw.count == 1, store.item(for: raw) != nil {
            store.goToBrowse()
            store.preview(character: raw)
            return
        }

        if let phrase = store.mergedPhrase(for: raw), raw.count > 1 {
            store.goToBrowse()
            store.presentPhraseInSidebar(phrase)
            return
        }

        store.goToSearchRoot()
        store.query = raw
        store.performSearch(customQuery: raw)
    }

    private func recentItemButton(_ item: String) -> some View {
        let phrase = store.mergedPhrase(for: item)
        let isPhrase = phrase != nil && item.count > 1

        return Button {
            store.activateBreadcrumbCharacter(item)
        } label: {
            VStack(spacing: 3) {
                Text(item)
                    .font(.system(size: isPhrase ? 18 : 30, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(isPhrase ? (phrase?.pinyin.isEmpty == false ? phrase?.pinyin ?? "Phrase" : "Phrase") : (store.item(for: item)?.pinyinText.isEmpty == false ? store.item(for: item)?.pinyinText ?? "" : " "))
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(width: isPhrase ? 118 : 66, height: 66)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func homeAction(title: String, text: String, icon: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 10) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(tint)
                    .frame(width: 38, height: 38)
                    .background(tint.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(ResponsiveFont.headline)
                        .foregroundStyle(.primary)
                    Text(text)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(3)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: 0)
            }
            .padding(12)
            .frame(maxWidth: .infinity, minHeight: 138, alignment: .topLeading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func statTile(_ title: String, _ value: String, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 17, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 32, height: 32)
                .background(tint.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            VStack(alignment: .leading, spacing: 1) {
                Text(value)
                    .font(.system(size: 23, weight: .bold, design: .rounded))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                Text(title)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Spacer(minLength: 0)
        }
        .padding(10)
        .frame(maxWidth: .infinity, minHeight: 64, alignment: .leading)
        .background(Color(.secondarySystemGroupedBackground))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private func homeEmptyRow(icon: String, title: String, text: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: icon)
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundStyle(Color.accentColor)
                    .frame(width: 40, height: 40)
                    .background(Color.accentColor.opacity(0.12))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                VStack(alignment: .leading, spacing: 3) {
                    Text(title)
                        .font(ResponsiveFont.headline)
                    Text(text)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer(minLength: 0)
                Image(systemName: "arrow.right")
                    .foregroundStyle(.secondary)
            }
            .padding(12)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }

    private func pageButton(_ collection: CharacterCollection) -> some View {
        Button {
            store.goToBrowse()
            store.selectBrowseCollection(id: collection.id)
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: collection.sourceType == .ocr ? "doc.text.viewfinder" : "doc.text")
                        .font(.system(size: 16, weight: .semibold))
                        .foregroundStyle(Color.accentColor)
                    Spacer(minLength: 0)
                    Text("\(collection.characters.count)")
                        .font(ResponsiveFont.caption.bold())
                        .foregroundStyle(.secondary)
                }
                Text(store.collectionDisplayName(collection.name))
                    .font(ResponsiveFont.body.bold())
                    .lineLimit(1)
                Text(collection.characters.prefix(10).joined(separator: " "))
                    .font(.system(size: 17, weight: .semibold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
                    .foregroundStyle(.primary.opacity(0.8))
            }
            .padding(10)
            .frame(maxWidth: .infinity, minHeight: 104, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
        }
        .buttonStyle(.plain)
    }
}
