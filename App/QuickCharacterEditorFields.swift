import SwiftUI

extension QuickCharacterEditorView {
    @ViewBuilder
    var dictionaryDetailsSection: some View {
        if horizontalSizeClass == .compact {
            VStack(alignment: .leading, spacing: 6) {
                Button {
                    detailsExpanded.toggle()
                } label: {
                    HStack(spacing: 8) {
                        RadixCompactChevronLabel(
                            chevronSystemName: detailsExpanded ? "chevron.down" : "chevron.right",
                            chevronFont: ResponsiveFont.caption.bold(),
                            chevronOpacity: 1,
                            width: 16
                        )
                        Text(detailsExpanded ? "Hide Dictionary Fields" : "Edit Dictionary Fields")
                            .font(ResponsiveFont.subheadline.weight(.semibold))
                        Spacer()
                    }
                    .padding(.vertical, 8)
                    .padding(.horizontal, 10)
                    .background(RadixTheme.secondaryBackground)
                    .clipShape(RoundedRectangle(cornerRadius: 8))
                    .contentShape(Rectangle())
                }
                .buttonStyle(.plain)

                if detailsExpanded {
                    dictionaryDetailsFields
                }
            }
        } else {
            dictionaryDetailsFields
        }
    }

    var dictionaryDetailsFields: some View {
        VStack(alignment: .leading, spacing: 6) {
            formField("Definition / Meanings") {
                TextField("Definition / Meanings", text: store.dataEditBinding(\.definition))
                    .textFieldStyle(.roundedBorder)
            }

            if horizontalSizeClass == .compact {
                compactDictionaryRows
            } else {
                regularDictionaryRows
            }
        }
        .controlSize(.small)
    }

    var compactDictionaryRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            compactFieldRow {
                formField("Pinyin") {
                    TextField("e.g. fā, fà", text: store.dataEditBinding(\.pinyin)).textFieldStyle(.roundedBorder)
                }
                compactFormField("Radical", width: 82) {
                    TextField("Radical", text: store.dataEditBinding(\.radical)).textFieldStyle(.roundedBorder)
                }
                compactFormField("Strokes", width: 76) {
                    TextField("Strokes", text: store.dataEditBinding(\.strokes)).textFieldStyle(.roundedBorder)
                }
                formField("Decomposition") {
                    TextField("Decomposition", text: store.dataEditBinding(\.decomposition)).textFieldStyle(.roundedBorder)
                }
            }

            compactFieldRow {
                compactFormField("Variant", width: 82) {
                    TextField("Variant", text: store.dataEditBinding(\.variant)).textFieldStyle(.roundedBorder)
                }
                formField("Additional Variants") {
                    TextField("e.g. 髮, 臺", text: store.dataEditBinding(\.additionalVariants)).textFieldStyle(.roundedBorder)
                }
            }

            formField("Related Characters") {
                TextField("Comma-separated", text: store.dataEditBinding(\.relatedCharacters)).textFieldStyle(.roundedBorder)
            }

            compactFieldRow {
                formField("Etymology") {
                    TextField("Details", text: store.dataEditBinding(\.etymologyDetails)).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .etymology)
                }
                .id(FocusedCharacterField.etymology)
                formField("Hints") {
                    TextField("Hint", text: store.dataEditBinding(\.etymologyHint)).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .hints)
                }
                .id(FocusedCharacterField.hints)
            }
        }
    }

    var regularDictionaryRows: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 8) {
                formField("Pinyin") {
                    TextField("e.g. fā, fà", text: store.dataEditBinding(\.pinyin)).textFieldStyle(.roundedBorder)
                }
                compactFormField("Radical", width: 90) {
                    TextField("Radical", text: store.dataEditBinding(\.radical)).textFieldStyle(.roundedBorder)
                }
                compactFormField("Strokes", width: 82) {
                    TextField("Strokes", text: store.dataEditBinding(\.strokes)).textFieldStyle(.roundedBorder)
                }
                formField("Decomposition") {
                    TextField("Decomposition", text: store.dataEditBinding(\.decomposition)).textFieldStyle(.roundedBorder)
                }
            }

            compactFieldRow {
                compactFormField("Variant", width: 100) {
                    TextField("Variant", text: store.dataEditBinding(\.variant)).textFieldStyle(.roundedBorder)
                }
                formField("Additional Variants") {
                    TextField("e.g. 髮, 臺", text: store.dataEditBinding(\.additionalVariants)).textFieldStyle(.roundedBorder)
                }
                formField("Related Characters") {
                    TextField("Comma-separated", text: store.dataEditBinding(\.relatedCharacters)).textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 8) {
                formField("Etymology") {
                    TextField("Details", text: store.dataEditBinding(\.etymologyDetails)).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .etymology)
                }
                formField("Hints") {
                    TextField("Hint", text: store.dataEditBinding(\.etymologyHint)).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .hints)
                }
            }
        }
    }

    @ViewBuilder
    func formField<Content: View>(_ label: String, @ViewBuilder content: () -> Content) -> some View {
        QuickEditField(label: label, content: content)
    }

    func compactFormField<Content: View>(_ label: String, width: CGFloat, @ViewBuilder content: () -> Content) -> some View {
        QuickEditField(label: label, width: width, content: content)
    }

    func compactFieldRow<Content: View>(@ViewBuilder content: () -> Content) -> some View {
        QuickEditFieldRow(content: content)
    }
}
