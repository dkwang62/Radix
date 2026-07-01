import SwiftUI

extension ConversationPracticeTranslationQuizSheet {
    var progressHeader: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            VStack(alignment: .leading, spacing: 2) {
                Text(library.set.title)
                    .font(ResponsiveFont.body.weight(.semibold))
                Text("\(currentIndex + 1) of \(quizItems.count)")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer(minLength: 8)

            Text("\(score) correct")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(Color.accentColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 5)
                .background(Color.accentColor.opacity(0.1))
                .clipShape(RoundedRectangle(cornerRadius: 8))
        }
    }

    var scriptPicker: some View {
        Picker("Script", selection: $selectedScriptFilter) {
            Text("Simplified").tag(ScriptFilter.simplified)
            Text("Traditional").tag(ScriptFilter.traditional)
        }
        .pickerStyle(.segmented)
    }

    var directionPicker: some View {
        Picker("Direction", selection: $direction) {
            ForEach(ConversationPracticeTranslationDirection.allCases) { direction in
                Text(direction.rawValue).tag(direction)
            }
        }
        .pickerStyle(.segmented)
    }

    var questionCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .center, spacing: 8) {
                Text(direction.prompt)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)

                Spacer(minLength: 8)

                if direction == .chineseToEnglish {
                    ConversationPracticeSpeechButton(
                        item: currentItem,
                        usesTraditionalScript: selectedScriptFilter == .traditional,
                        accessibilityLabel: "Read translation prompt"
                    )
                }
            }

            switch direction {
            case .englishToChinese:
                Text(currentItem.english)
                    .font(.system(size: RadixPlatform.isPhone ? 28 : 36, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.6)
                    .fixedSize(horizontal: false, vertical: true)
            case .chineseToEnglish:
                Text(displayText(currentItem.simplified))
                    .font(.system(size: RadixPlatform.isPhone ? 34 : 42, weight: .bold, design: .rounded))
                    .frame(maxWidth: .infinity, alignment: .center)
                    .multilineTextAlignment(.center)
                    .minimumScaleFactor(0.55)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground.opacity(0.62))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    func answerChoices(_ round: ConversationPracticeTranslationRound) -> some View {
        VStack(spacing: 8) {
            ForEach(round.choices) { choice in
                Button {
                    choose(choice)
                } label: {
                    answerChoiceLabel(choice)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 10)
                        .frame(maxWidth: .infinity, minHeight: 54, alignment: .leading)
                        .background(answerBackground(for: choice))
                        .clipShape(RoundedRectangle(cornerRadius: 9))
                        .overlay(
                            RoundedRectangle(cornerRadius: 9)
                                .stroke(answerTint(for: choice).opacity(hasAnsweredCurrent ? 0.5 : 0.18), lineWidth: 1)
                        )
                }
                .buttonStyle(.plain)
                .disabled(hasAnsweredCurrent)
            }
        }
    }

    func answerChoiceLabel(_ choice: ConversationPracticeItem) -> some View {
        HStack(spacing: 8) {
            Image(systemName: answerIcon(for: choice))
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(answerTint(for: choice))
                .frame(width: 24, height: 24)

            VStack(alignment: .leading, spacing: 3) {
                switch direction {
                case .englishToChinese:
                    Text(displayText(choice.simplified))
                        .font(ResponsiveFont.headline.weight(.semibold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.75)

                    Text(choice.pinyin)
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                case .chineseToEnglish:
                    Text(choice.english)
                        .font(ResponsiveFont.body.weight(.semibold))
                        .lineLimit(3)
                        .minimumScaleFactor(0.78)
                }
            }
        }
    }

    var feedbackSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label(selectedIsCorrect ? "Correct" : "Review this sentence", systemImage: selectedIsCorrect ? "checkmark.circle.fill" : "arrow.counterclockwise.circle")
                .font(ResponsiveFont.body.weight(.semibold))
                .foregroundStyle(selectedIsCorrect ? Color.green : Color.orange)

            VStack(alignment: .leading, spacing: 4) {
                HStack(alignment: .firstTextBaseline, spacing: 8) {
                    Text(displayText(currentItem.simplified))
                        .font(.system(size: 30, weight: .bold, design: .rounded))
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    ConversationPracticeSpeechButton(
                        item: currentItem,
                        usesTraditionalScript: selectedScriptFilter == .traditional,
                        accessibilityLabel: "Read translated sentence"
                    )
                }
                Text(currentItem.pinyin)
                    .font(ResponsiveFont.body.weight(.semibold))
                Text(currentItem.english)
                    .font(ResponsiveFont.body)
            }

            HStack(spacing: 8) {
                Button {
                    openPhrase(currentItem)
                } label: {
                    Label("Sentence Card", systemImage: "text.quote")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)

                Button {
                    advance()
                } label: {
                    Label(isLastQuestion ? "Finish" : "Next", systemImage: isLastQuestion ? "checkmark" : "arrow.right")
                        .font(ResponsiveFont.caption.weight(.semibold))
                }
                .buttonStyle(.borderedProminent)
                .tint(Color.accentColor)
            }

            let hints = store.linkedPracticeHints(for: currentItem)
            let characters = displayCharacters(for: currentItem, excludingPhrases: hints.phrases)
            if !characters.isEmpty {
                RadixTileFlowLayout(horizontalSpacing: 6, verticalSpacing: 6) {
                    ForEach(characters, id: \.self) { character in
                        Button {
                            openCharacter(character)
                        } label: {
                            Text(character)
                                .font(ResponsiveFont.body.weight(.semibold))
                                .frame(minWidth: 34, minHeight: 32)
                        }
                        .buttonStyle(.bordered)
                    }
                }
            }
        }
        .padding(12)
        .background(RadixTheme.secondaryBackground.opacity(0.42))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}
