import SwiftUI

extension CharacterInfoCard {
    func chipGuideBinding(for guide: ChipGuide) -> Binding<Bool> {
        Binding(
            get: { activeChipGuide == guide },
            set: { isPresented in
                if isPresented {
                    activeChipGuide = guide
                } else if activeChipGuide == guide {
                    activeChipGuide = nil
                }
            }
        )
    }

    var tierGuideView: some View {
        CharacterLearningTierGuide()
    }

    func chipGuideView(for guide: ChipGuide) -> some View {
        Text(guide.description(for: item))
            .font(chipGuideFont)
            .foregroundStyle(.secondary)
            .fixedSize(horizontal: false, vertical: true)
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: 220, alignment: .leading)
    }
}
