import SwiftUI

struct ConversationPracticeTranslationQuizSheet: View {
    static let sessionQuestionLimit = 20

    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject var store: RadixStore
    let library: ConversationPracticeLibrary
    @Binding var usesTraditionalScript: Bool
    @State var currentIndex = 0
    @State var sessionItems: [ConversationPracticeItem] = []
    @State var selectedAnswerID: String?
    @State var answered: [String: Bool] = [:]
    @State var inspectionPath: [ConversationPracticeInspectionRoute] = []
    @State var currentRound: ConversationPracticeTranslationRound?
    @State var selectedScriptFilter: ScriptFilter = .simplified
    @State var hasInitializedScript = false
    @State var direction: ConversationPracticeTranslationDirection = .englishToChinese

    var quizItems: [ConversationPracticeItem] {
        sessionItems.isEmpty ? Array(library.items.prefix(Self.sessionQuestionLimit)) : sessionItems
    }

    var currentItem: ConversationPracticeItem {
        let items = quizItems
        return items[min(currentIndex, items.count - 1)]
    }

    private var round: ConversationPracticeTranslationRound? {
        guard currentRound?.itemID == currentItem.id,
              currentRound?.scriptFilter == selectedScriptFilter,
              currentRound?.direction == direction else { return nil }
        return currentRound
    }

    var hasAnsweredCurrent: Bool {
        selectedAnswerID != nil
    }

    var selectedIsCorrect: Bool {
        selectedAnswerID == currentItem.id
    }

    var isLastQuestion: Bool {
        currentIndex >= quizItems.count - 1
    }

    var score: Int {
        answered.values.filter { $0 }.count
    }

    var defaultScriptFilter: ScriptFilter {
        ConversationPracticeScriptSupport.filter(usesTraditionalScript: usesTraditionalScript)
    }

    var body: some View {
        NavigationStack(path: $inspectionPath) {
            ScrollView {
                Group {
                    if let round {
                        VStack(alignment: .leading, spacing: 14) {
                            progressHeader
                            directionPicker
                            scriptPicker
                            questionCard
                            answerChoices(round)
                            if hasAnsweredCurrent {
                                feedbackSection
                            }
                        }
                    } else {
                        ProgressView()
                            .frame(maxWidth: .infinity, minHeight: 180)
                    }
                }
                .padding()
            }
            .background(RadixTheme.background)
            .navigationTitle("Translate")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Done") { dismiss() }
                }
            }
            .navigationDestination(for: ConversationPracticeInspectionRoute.self) { route in
                ConversationPracticeInspectionDestination(
                    route: route,
                    sourceTitle: "Translate",
                    onOpenCharacter: openCharacter
                )
                .environmentObject(store)
            }
            .onAppear {
                initializeScript()
                initializeSession()
                prepareCurrentRound()
            }
            .onChange(of: selectedScriptFilter) { _, newValue in
                changeScript(newValue)
            }
            .onChange(of: direction) { _, _ in
                selectedAnswerID = nil
                currentRound = nil
                prepareCurrentRound()
            }
            .onChange(of: usesTraditionalScript) { _, _ in
                let newValue = defaultScriptFilter
                guard selectedScriptFilter != newValue else { return }
                changeScript(newValue)
            }
        }
    }

    func dismissSheet() {
        dismiss()
    }
}
