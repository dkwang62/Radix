import SwiftUI

struct AppleStrokeKeyMap: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Stroke Keys: U I O / J K L")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)

            HStack(spacing: 4) {
                ForEach(AppleStrokeKeyGuide.topRow) { item in
                    AppleStrokeKeyCapsule(item: item)
                }
            }

            HStack(spacing: 4) {
                Spacer(minLength: 18)
                ForEach(AppleStrokeKeyGuide.bottomRow) { item in
                    AppleStrokeKeyCapsule(item: item)
                }
            }
        }
    }
}

struct AppleStrokeKeyCapsule: View {
    let item: AppleStrokeKeyGuide

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 12)
                .fill(
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.secondarySystemBackground)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            RoundedRectangle(cornerRadius: 12)
                .stroke(Color.primary.opacity(0.14), lineWidth: 1)

            VStack(spacing: 10) {
                HStack {
                    Spacer()
                    Text(item.stroke)
                        .font(.system(size: 28, weight: .bold))
                        .foregroundStyle(.secondary)
                }

                HStack {
                    Text(item.key)
                        .font(.system(size: 18, weight: .medium, design: .rounded))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity, minHeight: 88)
        .shadow(color: Color.black.opacity(0.08), radius: 1.5, y: 1)
    }
}

struct AppleStrokeExamplesView: View {
    let compact: Bool

    private let examples: [(character: String, code: String)] = [
        ("含", "ノ丶丶フ丨"),
        ("水", "丨フノ丶"),
        ("天", "一一丿"),
        ("下", "一丨丶"),
        ("扌", "一丨一"),
        ("中", "丨乛一"),
        ("川", "丿丨丨"),
        ("人", "丿丶"),
        ("久", "丿乛丶"),
        ("父", "丿丶丿"),
        ("文", "丶一丿"),
        ("方", "丶一乛"),
        ("又", "乛丶"),
        ("子", "乛丨一")
    ]

    private let columns = Array(repeating: GridItem(.flexible(minimum: 96, maximum: 140), spacing: 4), count: 6)

    init(compact: Bool = false) {
        self.compact = compact
    }

    var body: some View {
        if compact {
            ScrollView(.vertical, showsIndicators: true) {
                LazyVStack(alignment: .leading, spacing: 4) {
                    ForEach(examples, id: \.character) { example in
                        HStack(spacing: 10) {
                            Text(example.character)
                                .font(.system(size: 24, weight: .bold))
                                .frame(width: 28, alignment: .leading)
                            Text(example.code)
                                .font(.system(size: 17, weight: .bold, design: .rounded))
                                .foregroundStyle(.secondary)
                            Spacer(minLength: 0)
                        }
                        .padding(.horizontal, 8)
                        .padding(.vertical, 5)
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 8))
                    }
                }
            }
            .frame(maxHeight: 220)
        } else {
            LazyVGrid(columns: columns, alignment: .leading, spacing: 4) {
                ForEach(examples, id: \.character) { example in
                    VStack(alignment: .leading, spacing: 2) {
                        Text(example.character)
                            .font(.system(size: 28, weight: .bold))
                        Text(example.code)
                            .font(.system(size: 18, weight: .bold, design: .rounded))
                            .foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 6)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                }
            }
        }
    }
}

struct AppleStrokeKeyGuide: Identifiable {
    let stroke: String
    let key: String

    var id: String { stroke + key }

    static let topRow: [AppleStrokeKeyGuide] = [
        .init(stroke: "丶", key: "U"),
        .init(stroke: "乛", key: "I"),
        .init(stroke: "*", key: "O")
    ]

    static let bottomRow: [AppleStrokeKeyGuide] = [
        .init(stroke: "一", key: "J"),
        .init(stroke: "丨", key: "K"),
        .init(stroke: "丿", key: "L")
    ]
}

struct SearchExampleButton: View {
    let label: String
    let query: String
    let desc: String?
    let action: (String) -> Void

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
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
                        .font(isPhone ? .system(size: 12) : .system(size: 9))
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

