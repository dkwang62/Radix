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
            Text("Copy or open the instruction, paste the AI answer, then add the parsed phrases.")
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
            .background(Color(.secondarySystemBackground))
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
                .background(Color(.secondarySystemBackground))
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
