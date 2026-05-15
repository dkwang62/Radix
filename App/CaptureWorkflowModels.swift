import Foundation

struct CaptureWorkflowStep: Identifiable {
    var id: String { title }
    let title: String
    let detail: String
    let isComplete: Bool
    let systemImage: String
}

enum CaptureWorkflowStepBuilder {
    static func makeSteps(
        parserSource: PhraseParserSource,
        defaultAIName: String,
        promptCopied: Bool,
        output: String,
        importedCount: Int,
        candidateCount: Int
    ) -> [CaptureWorkflowStep] {
        let outputIsEmpty = output.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty

        return [
            CaptureWorkflowStep(
                title: "Choose",
                detail: parserSource.shortTitle,
                isComplete: true,
                systemImage: "checkmark.circle"
            ),
            CaptureWorkflowStep(
                title: "Copy",
                detail: promptCopied ? "Instruction copied" : "Open \(defaultAIName)",
                isComplete: promptCopied,
                systemImage: "doc.on.doc"
            ),
            CaptureWorkflowStep(
                title: "Paste",
                detail: outputIsEmpty ? "\(defaultAIName) answer" : "Answer pasted",
                isComplete: !outputIsEmpty,
                systemImage: "doc.on.clipboard"
            ),
            CaptureWorkflowStep(
                title: "Add",
                detail: importedCount == 0 ? "To My Phrases" : "\(importedCount) added",
                isComplete: importedCount > 0,
                systemImage: "plus.circle"
            ),
            CaptureWorkflowStep(
                title: "Check",
                detail: candidateCount == 0 ? "No list yet" : "\(candidateCount) shown",
                isComplete: candidateCount > 0,
                systemImage: "checklist"
            )
        ]
    }
}

enum CapturePhraseMode: Equatable {
    case apple
    case parser
}

enum PhraseParserSource: Equatable {
    case appleCandidates
    case chatGPTDerived

    var title: String {
        switch self {
        case .appleCandidates:
            return "Add Apple Candidates to My Phrases"
        case .chatGPTDerived:
            return "Add AI Suggestions to My Phrases"
        }
    }

    var shortTitle: String {
        switch self {
        case .appleCandidates:
            return "Apple candidates"
        case .chatGPTDerived:
            return "More phrases"
        }
    }

    func guidanceTitle(defaultAIName: String) -> String {
        switch self {
        case .appleCandidates:
            return "You chose Apple-derived phrases."
        case .chatGPTDerived:
            return "You chose \(defaultAIName) suggestions."
        }
    }

    func guidanceDetail(count: Int, defaultAIName: String) -> String {
        switch self {
        case .appleCandidates:
            let phraseText = count == 1 ? "1 phrase" : "\(count) phrases"
            return "Radix copies \(phraseText) to \(defaultAIName) so it can add pinyin and meaning. Copy \(defaultAIName)'s answer, then tap Paste \(defaultAIName) Answer and Add."
        case .chatGPTDerived:
            return "Radix copies the OCR text to \(defaultAIName) so it can find more phrases with pinyin and meaning. Copy \(defaultAIName)'s answer, then tap Paste \(defaultAIName) Answer and Add."
        }
    }
}
