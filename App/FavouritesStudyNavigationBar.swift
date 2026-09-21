import SwiftUI

extension FavouritesTab {
    var studySectionNavigationBar: some View {
        HStack(spacing: 6) {
            studyPrimarySectionButton("Recent", target: .recent)
            studyPrimarySectionButton("Favorites", target: .favorites)
            studyPrimarySectionButton("Pages", target: .savedPages)

            Menu {
                studyMoreSectionButton("Added Phrases", target: .addedPhrases, systemImage: "text.quote")
                studyMoreSectionButton(
                    "Conversation Practice",
                    target: .conversationPractice,
                    systemImage: "bubble.left.and.bubble.right"
                )
                studyMoreSectionButton("Sentences", target: .sentences, systemImage: "text.book.closed")
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
            .font(ResponsiveFont.caption.weight(isSelected ? .bold : .semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.72)
            .foregroundStyle(isSelected ? Color.white : Color.primary)
            .frame(maxWidth: .infinity, minHeight: 36)
            .background(
                RoundedRectangle(cornerRadius: 8)
                    .fill(isSelected ? RadixAccent.primary : RadixTheme.secondaryBackground)
            )
            .contentShape(RoundedRectangle(cornerRadius: 8))
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
        case .addedPhrases, .conversationPractice, .sentences, .checkpoints:
            return true
        case .recent, .favorites, .savedPages:
            return false
        }
    }
}
