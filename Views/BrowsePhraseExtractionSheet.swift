import SwiftUI

struct BrowsePhraseExtractionSheet: View {
    let collectionName: String
    let prompt: String
    @Binding var output: String
    let message: String?
    let onCopyPrompt: () -> Void
    let onOpenAI: () -> Void
    let onPaste: () -> Void
    let onAdd: () -> Void
    let onDone: () -> Void

    private var trimmedOutput: String {
        output.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                promptPanel
                outputPanel
            }
            .padding()
            .navigationTitle("Extract Phrases")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDone)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Copy Instruction", action: onCopyPrompt)
                    Button("Open AI", action: onOpenAI)
                    Button("Paste", action: onPaste)
                    Button("Add", action: onAdd)
                        .disabled(trimmedOutput.isEmpty)
                }
            }
        }
        .frame(minWidth: 380, minHeight: 560)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collectionName)
                .font(ResponsiveFont.headline.weight(.semibold))
                .lineLimit(1)
            Text("Find useful expressions that may be hard to notice—or too new or specialized for a traditional dictionary—then bring the phrases you want to keep back into Radix.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("Copy or open the instruction, paste the AI answer, review it, then tap Add.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            if let message {
                Text(message)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var promptPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("Instruction")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            ScrollView {
                Text(prompt)
                    .font(.system(size: 13, design: .monospaced))
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(10)
            }
            .frame(minHeight: 150, maxHeight: 210)
            .background(RadixTheme.secondaryBackground)
            .clipShape(RoundedRectangle(cornerRadius: 10))
        }
    }

    private var outputPanel: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text("AI Answer")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            TextEditor(text: $output)
                .font(.system(size: 15, design: .monospaced))
                .scrollContentBackground(.hidden)
                .padding(10)
                .background(RadixTheme.secondaryBackground)
                .clipShape(RoundedRectangle(cornerRadius: 10))
                .overlay(alignment: .topLeading) {
                    if output.isEmpty {
                        Text("Paste phrase records here, then tap Add.")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 18)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}

struct BrowsePageQuizSheet: View {
    let collectionName: String
    let questions: [PageQuizQuestion]
    let onDone: () -> Void
    @State private var currentIndex = 0
    @State private var selectedOption: String?
    @State private var correctCount = 0
    @State private var answeredQuestionIDs: Set<UUID> = []

    private var currentQuestion: PageQuizQuestion? {
        guard questions.indices.contains(currentIndex) else { return nil }
        return questions[currentIndex]
    }

    private var hasAnsweredCurrentQuestion: Bool {
        selectedOption != nil
    }

    private var isLastQuestion: Bool {
        currentIndex >= max(questions.count - 1, 0)
    }

    var body: some View {
        NavigationStack {
            Group {
                if questions.isEmpty {
                    emptyState
                } else {
                    quizContent
                }
            }
            .padding()
            .navigationTitle("Create Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDone)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    if !questions.isEmpty {
                        Text("\(correctCount)/\(answeredQuestionIDs.count)")
                            .font(ResponsiveFont.caption.weight(.semibold))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .frame(minWidth: 380, minHeight: 560)
    }

    private var quizContent: some View {
        VStack(alignment: .leading, spacing: 4) {
            header

            if let question = currentQuestion {
                questionCard(question)
                    .padding(.top, 14)

                options(for: question)
                    .padding(.top, 8)

                feedback(for: question)
                    .padding(.top, 8)

                Spacer(minLength: 12)

                footer
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(collectionName)
                .font(ResponsiveFont.headline.weight(.semibold))
                .lineLimit(1)
            Text("Answer on this screen. Radix marks it right or wrong immediately and explains the answer in English.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            ProgressView(value: Double(currentIndex + 1), total: Double(max(questions.count, 1)))
                .tint(Color.accentColor)
                .padding(.top, 8)
            Text("Question \(currentIndex + 1) of \(questions.count)")
                .font(ResponsiveFont.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
    }

    private func questionCard(_ question: PageQuizQuestion) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(questionKindLabel(question.kind))
                .font(ResponsiveFont.caption.weight(.bold))
                .foregroundStyle(.secondary)
            Text(question.character)
                .font(question.kind == .character ? .system(size: 42, weight: .semibold) : .system(size: 72, weight: .semibold))
                .frame(maxWidth: .infinity, alignment: .center)
            Text(question.prompt)
                .font(ResponsiveFont.title3.weight(.semibold))
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding(18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 18))
    }

    private func options(for question: PageQuizQuestion) -> some View {
        VStack(spacing: 10) {
            ForEach(question.options, id: \.self) { option in
                Button {
                    choose(option, for: question)
                } label: {
                    HStack {
                        Text(option)
                            .font(ResponsiveFont.body.weight(.semibold))
                            .foregroundStyle(optionTextColor(option, question: question))
                            .multilineTextAlignment(.leading)
                        Spacer()
                        if let selectedOption, selectedOption == option {
                            Image(systemName: option == question.correctOption ? "checkmark.circle.fill" : "xmark.circle.fill")
                                .foregroundStyle(option == question.correctOption ? Color.green : Color.orange)
                        } else if hasAnsweredCurrentQuestion, option == question.correctOption {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(Color.green)
                        }
                    }
                    .padding(14)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(optionBackground(option, question: question))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay {
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(optionBorder(option, question: question), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .disabled(hasAnsweredCurrentQuestion)
            }
        }
    }

    @ViewBuilder
    private func feedback(for question: PageQuizQuestion) -> some View {
        if let selectedOption {
            VStack(alignment: .leading, spacing: 8) {
                Label(
                    selectedOption == question.correctOption ? "Correct" : "Not quite",
                    systemImage: selectedOption == question.correctOption ? "checkmark.circle.fill" : "xmark.circle.fill"
                )
                .font(ResponsiveFont.headline.weight(.semibold))
                .foregroundStyle(selectedOption == question.correctOption ? Color.green : Color.orange)

                Text(question.explanation)
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(RadixTheme.secondaryBackground.opacity(0.65))
            .clipShape(RoundedRectangle(cornerRadius: 14))
        }
    }

    private var footer: some View {
        HStack {
            Button("Restart") {
                currentIndex = 0
                selectedOption = nil
                correctCount = 0
                answeredQuestionIDs = []
            }
            .buttonStyle(.bordered)

            Spacer()

            Button(isLastQuestion ? "Finish" : "Next") {
                if isLastQuestion {
                    onDone()
                } else {
                    currentIndex += 1
                    selectedOption = nil
                }
            }
            .buttonStyle(.borderedProminent)
            .disabled(!hasAnsweredCurrentQuestion)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 14) {
            Image(systemName: "questionmark.circle")
                .font(.system(size: 46, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("No quiz questions yet")
                .font(ResponsiveFont.title3.weight(.semibold))
            Text("Radix could not find enough dictionary-backed characters on this page to build answer choices.")
                .font(ResponsiveFont.body)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Done", action: onDone)
                .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }

    private func choose(_ option: String, for question: PageQuizQuestion) {
        guard selectedOption == nil else { return }
        selectedOption = option
        guard answeredQuestionIDs.insert(question.id).inserted else { return }
        if option == question.correctOption {
            correctCount += 1
        }
    }

    private func questionKindLabel(_ kind: PageQuizQuestion.Kind) -> String {
        switch kind {
        case .meaning: return "Meaning"
        case .pinyin: return "Pinyin"
        case .character: return "Character"
        }
    }

    private func optionTextColor(_ option: String, question: PageQuizQuestion) -> Color {
        guard hasAnsweredCurrentQuestion else { return .primary }
        if option == question.correctOption { return .green }
        if option == selectedOption { return .orange }
        return .primary
    }

    private func optionBackground(_ option: String, question: PageQuizQuestion) -> Color {
        guard hasAnsweredCurrentQuestion else { return RadixTheme.secondaryBackground }
        if option == question.correctOption { return Color.green.opacity(0.12) }
        if option == selectedOption { return Color.orange.opacity(0.12) }
        return RadixTheme.secondaryBackground
    }

    private func optionBorder(_ option: String, question: PageQuizQuestion) -> Color {
        guard hasAnsweredCurrentQuestion else { return RadixTheme.separator.opacity(0.5) }
        if option == question.correctOption { return Color.green.opacity(0.55) }
        if option == selectedOption { return Color.orange.opacity(0.55) }
        return RadixTheme.separator.opacity(0.35)
    }
}
