import SwiftUI

struct SearchExampleButton: View {
    let label: String
    let query: String
    let desc: String?
    let action: (String) -> Void

    private var isPhone: Bool {
        RadixPlatform.isPhone
    }

    init(label: String, query: String, desc: String? = nil, action: @escaping (String) -> Void) {
        self.label = label
        self.query = query
        self.desc = desc
        self.action = action
    }

    var body: some View {
        Button {
            action(query)
        } label: {
            VStack(alignment: .leading, spacing: isPhone ? 6 : 4) {
                HStack(spacing: 4) {
                    Text(label)
                        .font(isPhone ? ResponsiveFont.body : ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                    Text(query)
                        .font(isPhone ? ResponsiveFont.title3.bold() : ResponsiveFont.caption.bold())
                        .foregroundStyle(Color.accentColor)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                if let desc = desc {
                    Text(desc)
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                        .italic()
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
            }
            .padding(.horizontal, isPhone ? 14 : 12)
            .padding(.vertical, isPhone ? 12 : 8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.accentColor.opacity(0.05))
            .clipShape(RoundedRectangle(cornerRadius: 10))
            .overlay(
                RoundedRectangle(cornerRadius: 10)
                    .stroke(Color.accentColor.opacity(0.1), lineWidth: 1)
            )
        }
        .buttonStyle(.plain)
    }
}
