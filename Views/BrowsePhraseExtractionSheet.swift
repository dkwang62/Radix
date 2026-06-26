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
    let prompt: String
    @Binding var output: String
    let message: String?
    let onCopyPrompt: () -> Void
    let onOpenAI: () -> Void
    let onPaste: () -> Void
    let onDone: () -> Void

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header
                promptPanel
                outputPanel
            }
            .padding()
            .navigationTitle("Create Quiz")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDone)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Copy Instruction", action: onCopyPrompt)
                    Button("Open AI", action: onOpenAI)
                    Button("Paste", action: onPaste)
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
            Text("Create a standard Chinese practice quiz from this page. The default prompt asks the AI to use difficulty 5/10, ask one question at a time, and keep answers hidden until you reply.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Text("For the best hidden-answer practice, open the instruction in ChatGPT or Gemini. Automatic Radix output is useful as a quick quiz draft.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let message {
                Text(message)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
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
            Text("AI Quiz")
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
                        Text("Open the instruction in an AI app, or paste a quiz draft here.")
                            .foregroundStyle(.tertiary)
                            .padding(.top, 18)
                            .padding(.leading, 16)
                            .allowsHitTesting(false)
                    }
                }
        }
    }
}
