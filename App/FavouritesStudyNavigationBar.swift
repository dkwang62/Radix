import SwiftUI

extension FavouritesTab {
    var studySectionNavigationBar: some View {
        HStack(spacing: 6) {
            studyPrimarySectionButton("Sentences", target: .sentences)
            studyPrimarySectionButton("Conversation", target: .conversationPractice)
            studyPrimarySectionButton("Favorites", target: .favorites)

            Menu {
                studyMoreSectionButton("Recent", target: .recent, systemImage: "clock")
                studyMoreSectionButton("Added Phrases", target: .addedPhrases, systemImage: "text.quote")
                studyMoreSectionButton("Checkpoints", target: .checkpoints, systemImage: "clock.arrow.circlepath")
            } label: {
                studySectionNavigationLabel("More", isSelected: activeStudyNavigationTarget.isSecondary)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("More Study sections")
            .accessibilityValue(activeStudyNavigationTarget.isSecondary ? activeStudyNavigationTarget.title : "")
        }
        .frame(maxWidth: 440, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    private func studyPrimarySectionButton(_ title: String, target: StudyNavigationTarget) -> some View {
        Button {
            requestStudyNavigation(target)
        } label: {
            studySectionNavigationLabel(title, isSelected: activeStudyNavigationTarget == target)
        }
        .buttonStyle(.plain)
        .accessibilityValue(activeStudyNavigationTarget == target ? "Selected" : "")
    }

    private func studyMoreSectionButton(
        _ title: String,
        target: StudyNavigationTarget,
        systemImage: String
    ) -> some View {
        Button {
            requestStudyNavigation(target)
        } label: {
            Label(title, systemImage: activeStudyNavigationTarget == target ? "checkmark" : systemImage)
        }
    }

    private func studySectionNavigationLabel(_ title: String, isSelected: Bool) -> some View {
        Text(title)
            .font(studySectionNavigationFont.weight(isSelected ? .bold : .semibold))
            .lineLimit(1)
            .allowsTightening(true)
            .minimumScaleFactor(0.72)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? RadixAccent.primary : RadixTheme.secondaryBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
    }

    private var studySectionNavigationFont: Font {
        #if targetEnvironment(macCatalyst)
        ResponsiveFont.caption
        #else
        .system(size: isPhone ? 11 : 12)
        #endif
    }

    private var activeStudyNavigationTarget: StudyNavigationTarget {
        if showStudyCheckpoints { return .checkpoints }
        if let focusedStudySection {
            switch focusedStudySection {
            case .addedPhrases: return .addedPhrases
            case .conversationPractice: return .conversationPractice
            case .sentences: return .sentences
            }
        }
        switch studyGridScope {
        case .all: return .recent
        case .favorites: return .favorites
        case .savedPages: return .savedPages
        }
    }

    private func requestStudyNavigation(_ target: StudyNavigationTarget) {
        guard target != activeStudyNavigationTarget else { return }
        store.requestedStudyNavigationTarget = target
    }
}

private extension StudyNavigationTarget {
    var isSecondary: Bool {
        switch self {
        case .recent, .addedPhrases, .checkpoints:
            return true
        case .savedPages, .sentences, .conversationPractice, .favorites:
            return false
        }
    }
}
