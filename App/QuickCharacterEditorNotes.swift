import SwiftUI

extension QuickCharacterEditorView {
    @ViewBuilder
    var notesSection: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                RadixTermLabel("Notes / Sentences / Phrases", term: RadixTerm.notes)
                    .font(ResponsiveFont.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                if !store.dataEditNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    Image(systemName: "text.badge.checkmark")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                }
            }
            notesEditor()
        }
    }

    func notesEditor() -> some View {
        ZStack(alignment: .topLeading) {
            TextEditor(text: store.dataEditBinding(\.notes))
                .font(ResponsiveFont.body)
                .scrollContentBackground(.hidden)
                .padding(8)

            if store.dataEditNotes.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                Text("Type sentences, examples, and phrases you want to practise.")
                    .font(ResponsiveFont.body)
                    .foregroundStyle(.secondary)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 16)
                    .allowsHitTesting(false)
            }
        }
        .frame(minHeight: notesMinimumHeight, maxHeight: .infinity)
        .background(RadixTheme.secondaryBackground)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(RadixTheme.separator, lineWidth: 1)
        )
    }

    var notesMinimumHeight: CGFloat {
        if horizontalSizeClass == .compact {
            return detailsExpanded ? 220 : 360
        }
        return 320
    }
}
