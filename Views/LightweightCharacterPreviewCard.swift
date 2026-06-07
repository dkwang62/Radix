import SwiftUI

struct LightweightCharacterPreviewCard: View {
    @Environment(\.dismiss) private var dismiss
    let item: ComponentItem
    var showsCloseButton = false
    var onClose: (() -> Void)? = nil
    @State private var reloadToken = UUID()

    var body: some View {
        VStack(alignment: .leading, spacing: isPhone ? 14 : 10) {
            HStack(spacing: 8) {
                Text(displayPinyin)
                    .font(isPhone ? ResponsiveFont.title2.bold() : ResponsiveFont.title3.bold())
                    .foregroundStyle(Color.orange)
                    .lineLimit(2)
                    .minimumScaleFactor(0.75)
                Spacer(minLength: 0)
                Button {
                    reloadToken = UUID()
                } label: {
                    Image(systemName: "arrow.clockwise")
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .help("Replay stroke animation")

                if showsCloseButton {
                    Button {
                        if let onClose {
                            onClose()
                        } else {
                            dismiss()
                        }
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .buttonStyle(.bordered)
                    .controlSize(.small)
                    .help("Close")
                }
            }

            StrokeOrderWebView(character: item.character, reloadToken: reloadToken, canvasSize: animationCanvasSize)
                .frame(width: animationFrameSize, height: animationFrameSize)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(
                    RoundedRectangle(cornerRadius: 10)
                        .stroke(RadixTheme.separator, lineWidth: 0.5)
                )

            Text(displayDefinition)
                .font(isPhone ? ResponsiveFont.title3 : ResponsiveFont.body)
                .foregroundStyle(.primary)
                .multilineTextAlignment(.leading)
                .lineLimit(isPhone ? 8 : 5)
                .frame(maxWidth: animationFrameSize, alignment: .leading)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(width: animationFrameSize, alignment: .leading)
        .padding(isPhone ? 18 : 14)
    }

    private var isPhone: Bool {
        RadixPlatform.isPhone
    }

    private var animationCanvasSize: Int {
        isPhone ? 230 : 170
    }

    private var animationFrameSize: CGFloat {
        isPhone ? 250 : 190
    }

    private var displayPinyin: String {
        let value = item.pinyinText.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "—" : value
    }

    private var displayDefinition: String {
        let value = item.definition.trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? "No definition" : value
    }
}
