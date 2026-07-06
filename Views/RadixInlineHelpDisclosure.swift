import SwiftUI

struct RadixInlineHelpDisclosure: View {
    let title: String
    let message: String
    var systemImage = "info.circle"

    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Button {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            } label: {
                Label(title, systemImage: systemImage)
                    .font(ResponsiveFont.body.weight(.semibold))
                    .foregroundStyle(RadixAccent.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .buttonStyle(.plain)
            .onLongPressGesture {
                withAnimation(.easeInOut(duration: 0.18)) {
                    isExpanded.toggle()
                }
            }
            .accessibilityHint(isExpanded ? "Hides help" : "Shows help")

            if isExpanded {
                Text(message)
                    .font(RadixPlatform.isPhone ? ResponsiveFont.body : ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, alignment: .leading)
        .radixSurface(RadixTheme.secondaryBackground.opacity(0.70))
    }
}
