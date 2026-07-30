import SwiftUI

struct SentenceExampleEditSheet: View {
    @Environment(\.dismiss) private var dismiss
    let record: SentenceExampleRecord
    let onSave: (SentenceExampleRecord) -> Void

    @State private var chinese: String
    @State private var pinyin: String
    @State private var english: String
    @State private var targetCharacters: String
    @State private var targetPhrases: String
    @State private var tags: String
    @State private var notes: String

    init(record: SentenceExampleRecord, onSave: @escaping (SentenceExampleRecord) -> Void) {
        self.record = record
        self.onSave = onSave
        _chinese = State(initialValue: record.chinese)
        _pinyin = State(initialValue: record.pinyin ?? "")
        _english = State(initialValue: record.english ?? "")
        _targetCharacters = State(initialValue: record.targetCharacters.joined(separator: ", "))
        _targetPhrases = State(initialValue: record.targetPhrases.joined(separator: ", "))
        _tags = State(initialValue: record.tags.joined(separator: ", "))
        _notes = State(initialValue: record.notes)
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Sentence") {
                    TextEditor(text: $chinese)
                        .frame(minHeight: 72)
                    TextField("Pinyin", text: $pinyin, axis: .vertical)
                    TextField("English", text: $english, axis: .vertical)
                }

                Section("Learning Hints") {
                    TextField("Characters", text: $targetCharacters, axis: .vertical)
                    TextField("Phrases", text: $targetPhrases, axis: .vertical)
                    TextField("Tags", text: $tags, axis: .vertical)
                }

                Section("Notes") {
                    TextEditor(text: $notes)
                        .frame(minHeight: 82)
                }
            }
            .navigationTitle("Edit Sentence")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        save()
                    }
                    .disabled(!canSave)
                }
            }
        }
    }

    private var canSave: Bool {
        !trimmed(chinese).isEmpty
    }

    private func save() {
        var updated = record
        updated.chinese = trimmed(chinese)
        updated.pinyin = cleanOptional(pinyin)
        updated.english = cleanOptional(english)
        updated.targetCharacters = splitCharacters(targetCharacters)
        updated.targetPhrases = splitList(targetPhrases)
        updated.detectedCharacters = SentenceExampleRecord.detectChineseCharacters(in: updated.chinese)
        updated.tags = splitList(tags)
        updated.notes = trimmed(notes)
        onSave(updated)
        dismiss()
    }

    private func splitList(_ value: String) -> [String] {
        deduplicated(
            value.split { character in
                character == "," || character == ";" || character.isNewline
            }.map { trimmed(String($0)) }
        )
    }

    private func splitCharacters(_ value: String) -> [String] {
        let hasSeparators = value.contains(",") || value.contains(";") || value.contains { $0.isNewline }
        if hasSeparators {
            return splitList(value)
        }
        return deduplicated(
            value.map(String.init).map(trimmed).filter { !$0.isEmpty }
        )
    }

    private func cleanOptional(_ value: String) -> String? {
        let cleaned = trimmed(value)
        return cleaned.isEmpty ? nil : cleaned
    }

    private func trimmed(_ value: String) -> String {
        value.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private func deduplicated(_ values: [String]) -> [String] {
        var seen: Set<String> = []
        return values.filter { value in
            guard !value.isEmpty else { return false }
            return seen.insert(value).inserted
        }
    }
}
