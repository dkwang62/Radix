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
                        Image(systemName: detailsExpanded ? "chevron.down" : "chevron.right")
                            .font(ResponsiveFont.caption.bold())
                            .frame(width: 16)
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
                TextField("Definition / Meanings", text: $store.dataEditDefinition)
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
                    TextField("e.g. fā, fà", text: $store.dataEditPinyin).textFieldStyle(.roundedBorder)
                }
                compactFormField("Radical", width: 82) {
                    TextField("Radical", text: $store.dataEditRadical).textFieldStyle(.roundedBorder)
                }
                compactFormField("Strokes", width: 76) {
                    TextField("Strokes", text: $store.dataEditStrokes).textFieldStyle(.roundedBorder)
                }
                formField("Decomposition") {
                    TextField("Decomposition", text: $store.dataEditDecomposition).textFieldStyle(.roundedBorder)
                }
            }

            compactFieldRow {
                compactFormField("Variant", width: 82) {
                    TextField("Variant", text: $store.dataEditVariant).textFieldStyle(.roundedBorder)
                }
                formField("Additional Variants") {
                    TextField("e.g. 髮, 臺", text: $store.dataEditAdditionalVariants).textFieldStyle(.roundedBorder)
                }
            }

            formField("Related Characters") {
                TextField("Comma-separated", text: $store.dataEditRelatedCharacters).textFieldStyle(.roundedBorder)
            }

            compactFieldRow {
                formField("Etymology") {
                    TextField("Details", text: $store.dataEditEtymDetails).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .etymology)
                }
                .id(FocusedCharacterField.etymology)
                formField("Hints") {
                    TextField("Hint", text: $store.dataEditEtymHint).textFieldStyle(.roundedBorder)
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
                    TextField("e.g. fā, fà", text: $store.dataEditPinyin).textFieldStyle(.roundedBorder)
                }
                compactFormField("Radical", width: 90) {
                    TextField("Radical", text: $store.dataEditRadical).textFieldStyle(.roundedBorder)
                }
                compactFormField("Strokes", width: 82) {
                    TextField("Strokes", text: $store.dataEditStrokes).textFieldStyle(.roundedBorder)
                }
                formField("Decomposition") {
                    TextField("Decomposition", text: $store.dataEditDecomposition).textFieldStyle(.roundedBorder)
                }
            }

            compactFieldRow {
                compactFormField("Variant", width: 100) {
                    TextField("Variant", text: $store.dataEditVariant).textFieldStyle(.roundedBorder)
                }
                formField("Additional Variants") {
                    TextField("e.g. 髮, 臺", text: $store.dataEditAdditionalVariants).textFieldStyle(.roundedBorder)
                }
                formField("Related Characters") {
                    TextField("Comma-separated", text: $store.dataEditRelatedCharacters).textFieldStyle(.roundedBorder)
                }
            }

            HStack(spacing: 8) {
                formField("Etymology") {
                    TextField("Details", text: $store.dataEditEtymDetails).textFieldStyle(.roundedBorder)
                        .focused($focusedField, equals: .etymology)
                }
                formField("Hints") {
                    TextField("Hint", text: $store.dataEditEtymHint).textFieldStyle(.roundedBorder)
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
