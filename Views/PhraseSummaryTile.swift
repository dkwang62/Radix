import SwiftUI

struct PhraseSummaryTile: View {
    let phrase: PhraseItem

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            Text(phrase.word)
                .font(ResponsiveFont.body.bold())
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(phrase.pinyin.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty ? "-" : phrase.pinyin)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .lineLimit(2)
                .minimumScaleFactor(0.75)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .frame(maxWidth: .infinity, minHeight: 58, alignment: .leading)
        .background(Color(.secondarySystemBackground).opacity(0.65))
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(Color(.separator).opacity(0.45), lineWidth: 1)
        )
    }
}
