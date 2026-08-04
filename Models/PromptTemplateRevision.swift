import Foundation

enum PromptTemplateRevision {
    static func revisionPrompt(
        taskTitle: String,
        subjectType: PromptTaskSubjectType,
        currentTemplate: String,
        changeRequest: String
    ) -> String {
        """
        Revise this Radix AI prompt template.

        Task title:
        \(taskTitle.trimmingCharacters(in: .whitespacesAndNewlines))

        Subject type:
        \(subjectType.title)

        Requested change:
        \(changeRequest.trimmingCharacters(in: .whitespacesAndNewlines))

        Current template:
        ```text
        \(currentTemplate)
        ```

        Rules:
        1. Return the complete revised template, not a diff.
        2. Preserve Radix placeholders exactly, including braces, such as {capture_text}, {capture_chars}, {collection_name}, {sentence_zh}, {sentence_pinyin}, {sentence_en}, and similar fields.
        3. Keep the same task purpose unless the requested change explicitly says otherwise.
        4. Keep the template concise, direct, and usable in an AI chat.
        5. Do not include commentary, markdown fences, explanations, or alternatives.

        Return only the revised prompt template.
        """
    }

    static func revisedTemplate(from response: String) -> String {
        let trimmed = response.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else { return "" }

        if let fenced = firstFencedBlock(in: trimmed) {
            return fenced.trimmingCharacters(in: .whitespacesAndNewlines)
        }

        let labels = [
            "Revised template:",
            "Revised prompt template:",
            "Revised prompt:",
            "Template:",
            "Prompt:"
        ]
        for label in labels {
            if trimmed.localizedCaseInsensitiveContains(label),
               let range = trimmed.range(of: label, options: [.caseInsensitive]) {
                let remainder = trimmed[range.upperBound...]
                let cleaned = String(remainder).trimmingCharacters(in: .whitespacesAndNewlines)
                if !cleaned.isEmpty { return cleaned }
            }
        }

        return trimmed
    }

    private static func firstFencedBlock(in value: String) -> String? {
        guard let opening = value.range(of: "```") else { return nil }
        let afterOpening = value[opening.upperBound...]
        guard let closing = afterOpening.range(of: "```") else { return nil }
        var fenced = String(afterOpening[..<closing.lowerBound])
        if let firstNewline = fenced.firstIndex(where: \.isNewline) {
            let firstLine = fenced[..<firstNewline].trimmingCharacters(in: .whitespacesAndNewlines)
            if firstLine.range(of: #"^[A-Za-z0-9_-]+$"#, options: .regularExpression) != nil {
                fenced = String(fenced[fenced.index(after: firstNewline)...])
            }
        }
        return fenced
    }
}
