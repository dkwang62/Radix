import SwiftUI

struct BrowseTranslationReportSheet: View {
    let collectionName: String
    @Binding var report: String
    let updatedAt: Date?
    let onPaste: () -> Void
    let onSave: () -> Void
    let onClear: () -> Void
    let onDone: () -> Void

    private var trimmedReport: String {
        report.trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var body: some View {
        NavigationStack {
            VStack(alignment: .leading, spacing: 12) {
                header

                TextEditor(text: $report)
                    .font(.system(.body, design: .serif))
                    .scrollContentBackground(.hidden)
                    .padding(10)
                    .background(RadixTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                    .overlay(alignment: .topLeading) {
                        if report.isEmpty {
                            Text("Paste the AI translation here, then tap Save.")
                                .foregroundStyle(.tertiary)
                                .padding(.top, 18)
                                .padding(.leading, 16)
                                .allowsHitTesting(false)
                        }
                    }
            }
            .padding()
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done", action: onDone)
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button("Paste", action: onPaste)
                    Button("Clear", role: .destructive, action: onClear)
                        .disabled(trimmedReport.isEmpty)
                    Button("Save", action: onSave)
                        .disabled(trimmedReport.isEmpty)
                }
            }
        }
        .frame(minWidth: 360, minHeight: 460)
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(collectionName)
                .font(ResponsiveFont.headline.weight(.semibold))
                .lineLimit(1)
            Text("Keep a contextual translation with this page so you can revisit its meaning, tone, shorthand, and newer expressions alongside the original Chinese.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            if let updatedAt {
                Text("Saved \(updatedAt.formatted(date: .abbreviated, time: .shortened))")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            } else {
                Text("No saved translation yet.")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
