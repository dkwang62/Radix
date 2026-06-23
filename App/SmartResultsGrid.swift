import SwiftUI

struct SmartResultsGrid: View {
    @EnvironmentObject private var store: RadixStore
    let items: [ComponentItem]
    @Binding var currentPage: Int
    var onPreview: ((String) -> Void)? = nil
    var onSelect: (() -> Void)? = nil
    var readOnTap = false
    var emptyMessage: String? = "No matching characters."
    
    // Dynamic column calculation for Mac vs iPad
    private var columns: [GridItem] {
        let idiom = RadixPlatform.interfaceIdiom
        let minimum: CGFloat = idiom.isDesktop ? 40 : 32
        let maximum: CGFloat = idiom.isDesktop ? 80 : 64
        return Array(
            repeating: GridItem(.flexible(minimum: minimum, maximum: maximum), spacing: 0),
            count: idiom.searchResultColumnCount
        )
    }

    private var fontSize: CGFloat {
        RadixPlatform.interfaceIdiom.searchResultFontSize
    }

    private var columnsPerPage: Int {
        RadixPlatform.interfaceIdiom.searchResultColumnCount
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
            if let emptyMessage {
                Text(emptyMessage)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
        } else {
            VStack(alignment: .leading, spacing: 10) {
                if pageCount > 1 {
                    HStack {
                        Spacer()
                        Button {
                            currentPage = max(0, safePage - 1)
                        } label: {
                            Image(systemName: "chevron.left")
                                .frame(width: 30, height: 30)
                        }
                        .font(ResponsiveFont.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(safePage == 0)
                        .accessibilityLabel("Previous Page")

                        Text("Page \(safePage + 1) of \(pageCount)")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .frame(minWidth: 80)

                        Button {
                            currentPage = min(pageCount - 1, safePage + 1)
                        } label: {
                            Image(systemName: "chevron.right")
                                .frame(width: 30, height: 30)
                        }
                        .font(ResponsiveFont.caption)
                        .buttonStyle(.bordered)
                        .controlSize(.small)
                        .disabled(safePage + 1 >= pageCount)
                        .accessibilityLabel("Next Page")
                    }
                }

                LazyVGrid(columns: columns, spacing: 0) {
                    ForEach(pagedItems, id: \.character) { item in
                        let isActive = item.character == store.previewCharacter
                        Button {
                            onPreview?(item.character)
                            store.preview(character: item.character, announce: !readOnTap)
                            if readOnTap {
                                store.speakCharacter(item.character)
                            }
                            onSelect?()
                        } label: {
                            VStack(spacing: 2) {
                                Text(item.character)
                                    .font(.system(size: fontSize))
                                    .copyCharacterContextMenu(item.character, pinyin: item.pinyinText)
                                Text(item.pinyinText.isEmpty ? " " : item.pinyinText)
                                    .font(.system(size: 13, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .lineLimit(1)
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 6)
                            .background(isActive ? Color.accentColor.opacity(0.18) : RadixTheme.secondaryBackground)
                            .clipShape(RoundedRectangle(cornerRadius: 6))
                            .overlay(
                                RoundedRectangle(cornerRadius: 6)
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
                    }
                }
                .frame(maxHeight: CGFloat(rowsPerPage) * RadixPlatform.interfaceIdiom.searchResultRowHeight)
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
