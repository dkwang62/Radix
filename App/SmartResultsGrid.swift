import SwiftUI

struct CharacterRow: View {
    let item: ComponentItem
    let isFavorite: Bool

    var body: some View {
        HStack(spacing: 12) {
            Text(item.character)
                .font(.system(size: 26))
                .frame(width: 34)
                .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
            VStack(alignment: .leading, spacing: 2) {
                Text(item.pinyinText.isEmpty ? "-" : item.pinyinText)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(item.definition.isEmpty ? "No definition" : item.definition)
                    .font(.callout)
                    .lineLimit(1)
            }
            Spacer()
            if isFavorite {
                Image(systemName: "star.fill")
                    .foregroundStyle(.yellow)
            }
        }
    }
}

struct SmartResultsGrid: View {
    @EnvironmentObject private var store: RadixStore
    let items: [ComponentItem]
    @Binding var currentPage: Int
    var onPreview: ((String) -> Void)? = nil
    var onSelect: (() -> Void)? = nil
    
    // Dynamic column calculation for Mac vs iPad
    private var columns: [GridItem] {
        #if targetEnvironment(macCatalyst)
        return Array(repeating: GridItem(.flexible(minimum: 40, maximum: 80), spacing: 10), count: 15)
        #else
        // iPhone: reduce to 8 columns to avoid pinyin wrapping
        return Array(repeating: GridItem(.flexible(minimum: 32, maximum: 64), spacing: 8), count: 8)
        #endif
    }

    private var fontSize: CGFloat {
        #if targetEnvironment(macCatalyst)
        return 28
        #else
        return 24
        #endif
    }

    private var columnsPerPage: Int {
        #if targetEnvironment(macCatalyst)
        return 15
        #else
        return 8
        #endif
    }

    private let rowsPerPage = 5

    private var pageSize: Int {
        columnsPerPage * rowsPerPage
    }

    private var pageCount: Int {
        max(1, Int(ceil(Double(items.count) / Double(pageSize))))
    }

    private var safePage: Int {
        min(currentPage, pageCount - 1)
    }

    private var pagedItems: ArraySlice<ComponentItem> {
        let start = safePage * pageSize
        let end = min(start + pageSize, items.count)
        return items[start..<end]
    }

    var body: some View {
        if items.isEmpty {
            Text("No results for current filters.")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if pageCount > 1 {
                    HStack {
                        Spacer()
                        Button("◀ Prev") {
                            currentPage = max(0, safePage - 1)
                        }
                        .font(ResponsiveFont.caption)
                        .disabled(safePage == 0)

                        Text("Page \(safePage + 1) of \(pageCount)")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 80)

                        Button("Next ▶") {
                            currentPage = min(pageCount - 1, safePage + 1)
                        }
                        .font(ResponsiveFont.caption)
                        .disabled(safePage + 1 >= pageCount)
                    }
                }

                LazyVGrid(columns: columns, spacing: 6) {
                    ForEach(pagedItems, id: \.character) { item in
                        let isActive = item.character == store.previewCharacter || item.character == store.selectedCharacter
                        Button {
                            onPreview?(item.character)
                            store.preview(character: item.character)
                            onSelect?()
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.character)
                                    .font(.system(size: fontSize))
                                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                                Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.accentColor.opacity(0.18) : Color(.secondarySystemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 10))
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(isActive ? Color.accentColor : Color.clear, lineWidth: 2)
                            )
                            .overlay(alignment: .topTrailing) {
                                if store.isFavorite(item.character) {
                                    Image(systemName: "star.fill")
                                        .font(.system(size: 14))
                                        .foregroundStyle(.yellow)
                                        .padding(6)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                        .simultaneousGesture(
                            TapGesture(count: 2).onEnded {
                                store.select(character: item.character)
                            }
                        )
                    }
                }
                .frame(maxHeight: {
                    #if targetEnvironment(macCatalyst)
                    return 5 * 56
                    #else
                    return 5 * 52
                    #endif
                }())
            }
            .padding(.vertical, 10)
            .onChange(of: items.count) { _, _ in
                if currentPage >= pageCount {
                    currentPage = max(0, pageCount - 1)
                }
            }
        }
    }

}

