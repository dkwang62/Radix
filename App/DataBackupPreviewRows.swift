import SwiftUI

struct BackupCharacterTile: View {
    let character: String
    let pinyin: String
    let onSelect: () -> Void

    var body: some View {
        Button(action: onSelect) {
            VStack(spacing: 4) {
                Text(character)
                    .font(.system(size: 28, weight: .bold))
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(pinyin.isEmpty ? "-" : pinyin)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
        .buttonStyle(.plain)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58)
        .background(RadixTheme.secondaryBackground.opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(RadixTheme.separator.opacity(0.45), lineWidth: 1)
        )
        .copyCharacterContextMenu(character, pinyin: pinyin)
    }
}

struct BackupPhraseRow: View {
    let phrase: PhraseItem
    let onSelect: () -> Void
    var showsReviewStatus: Bool = false

    var body: some View {
        Button(action: onSelect) {
            PhraseSummaryTile(phrase: phrase, showsReviewStatus: showsReviewStatus)
        }
        .buttonStyle(.plain)
        .phraseContextMenu(phrase)
    }
}

struct BackupSummaryLine: View {
    let title: String
    let value: String

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            Text(title)
                .font(ResponsiveFont.caption.bold())
            Spacer()
            Text(value)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.trailing)
        }
    }
}

enum BackupPreviewSort {
    static func key(primary: String, fallback: String) -> String {
        let value = primary.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? fallback : primary
        return value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: .current)
    }
}
