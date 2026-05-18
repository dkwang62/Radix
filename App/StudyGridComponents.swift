import SwiftUI

struct StudyPhraseSingleTile: View {
    let phraseText: String
    let pinyin: String
    let marker: StudyPhraseMarker
    let isActive: Bool
    let onPreview: () -> Void
    let onToggleFavorite: () -> Void

    private var isFavorite: Bool {
        marker == .favorite
    }

    var body: some View {
        PhraseSummaryTile(
            phraseText: phraseText,
            pinyin: pinyin,
            isFavorite: isFavorite,
            isActive: isActive,
            minimumHeight: RadixTileMetrics.compactHeight,
            textAlignment: .center,
            onSelect: onPreview,
            onToggleFavorite: onToggleFavorite
        )
        .frame(height: RadixTileMetrics.compactHeight)
    }
}
