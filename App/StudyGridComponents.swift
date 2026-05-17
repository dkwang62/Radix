import SwiftUI

struct StudyPhraseMarkerTile: View {
    let marker: StudyPhraseMarker

    var isFavorite: Bool {
        marker == .favorite
    }

    var body: some View {
        VStack(spacing: 2) {
            Image(systemName: isFavorite ? RadixIcon.saved : RadixIcon.unsaved)
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(isFavorite ? Color.yellow : Color.secondary.opacity(0.72))
            Text(" ")
                .font(.system(size: 11, weight: .semibold))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 6)
        .background(isFavorite ? Color.yellow.opacity(0.12) : Color(.secondarySystemBackground).opacity(0.44))
        .clipShape(RoundedRectangle(cornerRadius: 6))
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .stroke(isFavorite ? Color.yellow.opacity(0.65) : Color.secondary.opacity(0.22), lineWidth: 2)
        )
        .accessibilityLabel(isFavorite ? "Favorite phrase" : "Recent phrase")
    }
}

struct StudyPhraseFlowLayout: Layout {
    var horizontalSpacing: CGFloat = 6
    var verticalSpacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let maxWidth = proposal.width ?? subviews.map { $0.sizeThatFits(.unspecified).width }.reduce(0, +)
        var lineWidth: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalWidth: CGFloat = 0
        var totalHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedWidth = lineWidth == 0 ? size.width : lineWidth + horizontalSpacing + size.width

            if proposedWidth > maxWidth, lineWidth > 0 {
                totalWidth = max(totalWidth, lineWidth)
                totalHeight += lineHeight + verticalSpacing
                lineWidth = size.width
                lineHeight = size.height
            } else {
                lineWidth = proposedWidth
                lineHeight = max(lineHeight, size.height)
            }
        }

        totalWidth = max(totalWidth, lineWidth)
        totalHeight += lineHeight
        return CGSize(width: min(totalWidth, maxWidth), height: totalHeight)
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        var origin = CGPoint(x: bounds.minX, y: bounds.minY)
        var lineHeight: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            let proposedMaxX = origin.x == bounds.minX ? origin.x + size.width : origin.x + horizontalSpacing + size.width

            if proposedMaxX > bounds.maxX, origin.x > bounds.minX {
                origin.x = bounds.minX
                origin.y += lineHeight + verticalSpacing
                lineHeight = 0
            } else if origin.x > bounds.minX {
                origin.x += horizontalSpacing
            }

            subview.place(
                at: origin,
                proposal: ProposedViewSize(width: min(size.width, bounds.width), height: size.height)
            )
            origin.x += size.width
            lineHeight = max(lineHeight, size.height)
        }
    }
}
