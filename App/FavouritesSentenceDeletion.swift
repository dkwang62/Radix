import SwiftUI

struct SentenceExampleDeletionAlert: ViewModifier {
    @Binding var pendingDeletion: PendingSentenceExampleDeletion?
    let onDelete: (SentenceExampleRecord) -> Void

    func body(content: Content) -> some View {
        content.alert("Delete Sentence?", isPresented: isPresented) {
            Button("Cancel", role: .cancel) {
                pendingDeletion = nil
            }
            Button("Delete Sentence", role: .destructive) {
                if let record = pendingDeletion?.record {
                    onDelete(record)
                }
                pendingDeletion = nil
            }
        } message: {
            Text(message)
        }
    }

    private var isPresented: Binding<Bool> {
        Binding(
            get: { pendingDeletion != nil },
            set: { if !$0 { pendingDeletion = nil } }
        )
    }

    private var message: String {
        guard let pendingDeletion else {
            return "This permanently deletes this saved sentence from Study."
        }
        return "This permanently deletes this saved sentence from Study.\n\n\(pendingDeletion.record.chinese)"
    }
}
