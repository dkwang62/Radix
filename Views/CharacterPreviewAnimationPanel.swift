import SwiftUI

struct CharacterPreviewAnimationPanel: View {
    @EnvironmentObject private var store: RadixStore

    let item: ComponentItem
    let allVariants: [ComponentItem]
    let activeVariant: ComponentItem?
    let isVertical: Bool
    let onSelectCharacter: (String) -> Void

    var body: some View {
        if let activeVariant {
            variantAnimations(activeVariant: activeVariant)
        } else {
            singleAnimation
        }
    }

    private func variantAnimations(activeVariant: ComponentItem) -> some View {
        let chars = store.isTraditional(item.character)
            ? [activeVariant.character, item.character]
            : [item.character, activeVariant.character]

        let animContainer = AnyLayout(isVertical
            ? AnyLayout(HStackLayout(spacing: 0))
            : AnyLayout(VStackLayout(spacing: 0)))

        return animContainer {
            ForEach(chars, id: \.self) { char in
                VStack(spacing: 0) {
                    StrokeAnimationHeaderLabel(text: variantAnimationTitle(for: char))
                        .padding(.vertical, 6)

                    StrokeOrderWebView(
                        character: char,
                        reloadToken: StrokeAnimationToken.stable(for: "preview-variant-\(char)-\(isVertical)"),
                        canvasSize: isVertical ? 120 : 90
                    )
                    .frame(maxWidth: .infinity)
                    .frame(height: isVertical ? 120 : 100)
                }
                .background(Color.secondary.opacity(0.05))
                .border(Color(.separator).opacity(0.2), width: 0.5)
                .contentShape(Rectangle())
                .onTapGesture {
                    onSelectCharacter(char)
                }
            }
        }
        .frame(width: isVertical ? nil : 100)
        .frame(maxWidth: isVertical ? .infinity : 100)
    }

    private var singleAnimation: some View {
        VStack(spacing: 0) {
            StrokeAnimationHeaderLabel(text: singleAnimationTitle(for: item))
                .padding(.vertical, 6)

            StrokeOrderWebView(
                character: item.character,
                reloadToken: StrokeAnimationToken.stable(for: "preview-single-\(item.character)-\(isVertical)"),
                canvasSize: 120
            )
            .frame(height: 130)
            .frame(maxWidth: .infinity)
        }
        .background(Color.secondary.opacity(0.05))
        .border(Color(.separator).opacity(0.2), width: 0.5)
        .frame(width: isVertical ? nil : 130)
        .frame(maxWidth: isVertical ? .infinity : 130)
    }

    private func variantAnimationTitle(for character: String) -> String {
        guard let strokes = store.item(for: character)?.strokes else {
            return " "
        }
        let script = store.isTraditional(character) ? "繁" : "简"
        return "\(script)\(strokes)"
    }

    private func singleAnimationTitle(for item: ComponentItem) -> String {
        guard let strokes = item.strokes else {
            return " "
        }
        return strokeCountText(strokes)
    }

    private func strokeCountText(_ strokes: Int) -> String {
        let unit = strokes == 1 ? "stroke" : "strokes"
        return "\(strokes) \(unit)"
    }
}
