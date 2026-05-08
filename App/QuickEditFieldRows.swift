import SwiftUI

struct QuickEditField<Content: View>: View {
    let label: String
    var width: CGFloat?
    var allowLabelScaling = true
    @ViewBuilder let content: Content

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label)
                .font(ResponsiveFont.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(allowLabelScaling ? 0.85 : 1)
            content
        }
        .frame(width: width)
        .frame(maxWidth: width == nil ? .infinity : nil)
    }
}

struct QuickEditFieldRow<Content: View>: View {
    @ViewBuilder let content: Content

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            content
        }
    }
}
