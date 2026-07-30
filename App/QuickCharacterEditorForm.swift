import SwiftUI

extension QuickCharacterEditorView {
    @ViewBuilder
    var editorForm: some View {
        if horizontalSizeClass == .compact && detailsExpanded {
            scrollableEditorForm
        } else {
            fixedEditorForm
        }
    }

    var fixedEditorForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            editorErrorMessage

            notesSection
                .frame(maxHeight: .infinity)

            dictionaryDetailsSection

            if hasCharacterManagementAction {
                Divider()

                actionRow
            }
        }
        .padding(.horizontal, 12)
        .padding(.top, 8)
        .padding(.bottom, 8)
        .font(ResponsiveFont.body)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    var scrollableEditorForm: some View {
        VStack(alignment: .leading, spacing: 8) {
            ScrollViewReader { proxy in
                ScrollView {
                    VStack(alignment: .leading, spacing: 8) {
                        editorErrorMessage

                        notesSection
                            .frame(height: notesMinimumHeight)

                        dictionaryDetailsSection

                        Spacer(minLength: 120)
                    }
                    .padding(.horizontal, 12)
                    .padding(.top, 8)
                    .padding(.bottom, 8)
                    .font(ResponsiveFont.body)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                }
                .onChange(of: focusedField) { _, field in
                    guard let field else { return }
                    withAnimation(.easeInOut(duration: 0.2)) {
                        proxy.scrollTo(field, anchor: .center)
                    }
                }
            }

            if hasCharacterManagementAction {
                Divider()

                actionRow
                    .padding(.horizontal, 12)
                    .padding(.bottom, 8)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    @ViewBuilder
    var editorErrorMessage: some View {
        if let editorError {
            Text(editorError)
                .font(ResponsiveFont.caption)
                .foregroundStyle(.red)
                .padding(.horizontal)
        }
    }
}
