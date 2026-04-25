import SwiftUI

struct FavouritesTab: View {
    private static let addedDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter
    }()

    private static let relativeFormatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .full
        return formatter
    }()

    @EnvironmentObject private var store: RadixStore
    @EnvironmentObject private var entitlement: EntitlementManager
    let onExportProfile: () -> Void
    let onImportProfile: () -> Void
    let onRequirePro: (EntitlementManager.FeatureGate) -> Void

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 6) {
                HStack {
                    Spacer()
                    HStack(spacing: 12) {
                        Button(action: onExportProfile) {
                            Image(systemName: "square.and.arrow.up")
                        }
                        Button(action: onImportProfile) {
                            Image(systemName: "square.and.arrow.down")
                        }
                    }
                    .font(ResponsiveFont.body)
                    .foregroundStyle(Color.accentColor)
                }
                Text("Whatever is remembered will be forgotten once the app is closed. Add to Favorites to keep.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding()

            if store.favoriteItems.isEmpty && store.favoritePhrasesItems.isEmpty {
                ContentUnavailableView("No Favorites", systemImage: "star.slash", description: Text("Tap the star icon on any character or phrase to add it to this list."))
            } else {
                ScrollView {
                    VStack(alignment: .leading, spacing: 18) {
                    if isPhone, let current = store.previewCharacter {
                        VStack(alignment: .leading, spacing: 8) {
                            standardPhoneCharacterPreview(
                                character: current,
                                selectedCharacter: store.selectedCharacter,
                                showAddToMemoryButton: false,
                                onClear: { store.previewCharacter = nil }
                            )
                        }
                    }

                    if !store.favoriteItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Characters (\(store.favoriteItems.count))")
                                .font(ResponsiveFont.caption.bold())
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: favoriteCharacterColumns, spacing: 8) {
                                ForEach(store.favoriteItems, id: \.character) { item in
                                    favoriteCharacterCell(item)
                                }
                            }
                        }
                    }

                    if !store.favoritePhrasesItems.isEmpty {
                        VStack(alignment: .leading, spacing: 8) {
                            Text("Phrases (\(store.favoritePhrasesItems.count))")
                                .font(ResponsiveFont.caption.bold())
                                .foregroundStyle(.secondary)

                            ScrollView {
                                LazyVStack(spacing: 0) {
                                    ForEach(store.favoritePhrasesItems, id: \.word) { phrase in
                                        favoritePhraseRow(phrase)
                                        Divider()
                                    }
                                }
                            }
                            .frame(height: favoritePhraseViewportHeight)
                            .background(Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                        }
                    }
                }
                    .padding(.horizontal)
                    .padding(.bottom, 20)
                }
            }
        }
    }

    private var favoriteCharacterColumns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 44, maximum: 82), spacing: 10), count: 10)
        #else
        if isPhone {
            return Array(repeating: GridItem(.flexible(minimum: 44, maximum: 72), spacing: 8), count: 4)
        }
        return Array(repeating: GridItem(.flexible(minimum: 44, maximum: 78), spacing: 8), count: 8)
        #endif
    }

    private func favoriteCharacterCell(_ item: ComponentItem) -> some View {
        let isActive = item.character == store.previewCharacter || item.character == store.selectedCharacter

        return Button {
            store.preview(character: item.character, announce: false)
        } label: {
            VStack(spacing: 2) {
                Text(item.character)
                    .font(.system(size: isPhone ? 28 : 30, weight: .bold))
                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 6)
            .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
            )
            .overlay(alignment: .topTrailing) {
                Image(systemName: "star.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(.yellow)
                    .padding(6)
            }
        }
        .buttonStyle(.plain)
        .simultaneousGesture(
            TapGesture(count: 2).onEnded {
                store.select(character: item.character)
            }
        )
    }

    private func favoritePhraseRow(_ phrase: PhraseItem) -> some View {
        let leadingColumnWidth: CGFloat = {
            #if targetEnvironment(macCatalyst)
            return 150
            #else
            return isPhone ? 96 : 120
            #endif
        }()

        return HStack(alignment: .top, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(phrase.word)
                    .font(ResponsiveFont.body.bold())
                Text(phrase.pinyin.isEmpty ? "-" : phrase.pinyin)
                    .font(ResponsiveFont.caption)
                    .lineLimit(2)
                    .fixedSize(horizontal: false, vertical: true)
                    .minimumScaleFactor(0.85)
                    .foregroundStyle(.secondary)
            }
            .frame(width: leadingColumnWidth, alignment: .leading)

            VStack(alignment: .leading, spacing: 4) {
                Text(phrase.meanings.isEmpty ? "No meaning" : phrase.meanings)
                    .font(ResponsiveFont.body)
                if !phrase.notes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Text(phrase.notes)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }
            }
            .fixedSize(horizontal: false, vertical: true)
            .frame(maxWidth: .infinity, alignment: .leading)
            .layoutPriority(1)
        }
        .padding(.horizontal, 10)
        .frame(maxWidth: .infinity, minHeight: favoritePhraseRowHeight, alignment: .leading)
        .contentShape(Rectangle())
        .phraseContextMenu(phrase)
    }

    private var favoritePhraseRowHeight: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 84
        #else
        return isPhone ? 72 : 82
        #endif
    }

    private var favoritePhraseViewportHeight: CGFloat {
        let visibleRows = min(max(store.favoritePhrasesItems.count, 1), 6)
        return (favoritePhraseRowHeight * CGFloat(visibleRows)) + 5
    }

    private func favoriteAddedLabel(for character: String) -> String {
        guard let addedAt = store.favoriteAddedDate(for: character) else {
            return "Saved before dates were tracked"
        }

        let relative = Self.relativeFormatter.localizedString(for: addedAt, relativeTo: Date())
        let absolute = Self.addedDateFormatter.string(from: addedAt)
        return "Added \(relative) (\(absolute))"
    }
}

struct ProLockedView: View {
    let featureName: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("\(featureName) is a Pro feature")
                .font(.headline)
            Text("Upgrade to unlock this feature and future Pro updates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Upgrade to Pro", action: onUpgrade)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
