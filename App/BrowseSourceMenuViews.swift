import SwiftUI

struct BrowseImageScriptToggle: View {
    @Binding var mode: String

    var body: some View {
        CompactScriptToggle(
            isTraditional: mode == "traditional",
            accessibilityLabel: "Image script"
        ) {
            mode = mode == "traditional" ? "simplified" : "traditional"
        }
    }
}

struct CollectionPageActionsMenu: View {
    private enum PendingAIMethod {
        case checkOCRManually
        case checkOCRAutomatically
        case extractManually
        case extractAutomatically
        case translateManually
        case translateAutomatically
        case quizManually
        case quizAutomatically
    }

    let collection: CharacterCollection
    let onEdit: () -> Void
    let onCheckOCR: (() -> Void)?
    let hasGeminiAPIKey: Bool
    let onCheckOCRAutomatically: () -> Void
    let onChoosePhrases: () -> Void
    let onViewTranslation: () -> Void
    let onManualExtract: () -> Void
    let onAIExtract: () -> Void
    let onTranslate: () -> Void
    let onTranslateAndSave: () -> Void
    let onCreateQuizManually: () -> Void
    let onCreateQuizAutomatically: () -> Void
    @State private var showsAIOrientation = false
    @State private var pendingAIMethod: PendingAIMethod?

    var body: some View {
        Menu {
            Section("Page") {
                Button {
                    onEdit()
                } label: {
                    Label("Edit Page", systemImage: "pencil")
                }

                Button {
                    onChoosePhrases()
                } label: {
                    Label("Choose Page Phrases", systemImage: "text.quote")
                }

                Button {
                    onViewTranslation()
                } label: {
                    Label(
                        collection.translationReport == nil ? "Save Translation" : "View Translation",
                        systemImage: collection.translationReport == nil ? "doc.badge.plus" : "doc.text"
                    )
                }
            }

            Section("AI Tasks") {
                if onCheckOCR != nil {
                    Menu {
                        aiMethodButton(
                            manualMethod: .checkOCRManually,
                            automaticMethod: .checkOCRAutomatically
                        )
                    } label: {
                        Label("Check OCR", systemImage: "text.viewfinder")
                    }
                }

                Menu {
                    aiMethodButton(
                        manualMethod: .extractManually,
                        automaticMethod: .extractAutomatically
                    )
                } label: {
                    Label("Extract Phrases", systemImage: "text.badge.plus")
                }

                Menu {
                    aiMethodButton(
                        manualMethod: .translateManually,
                        automaticMethod: .translateAutomatically
                    )
                } label: {
                    Label("Translate Page", systemImage: "translate")
                }

                Menu {
                    aiMethodButton(
                        manualMethod: .quizManually,
                        automaticMethod: .quizAutomatically
                    )
                } label: {
                    Label("Create Quiz", systemImage: "questionmark.circle")
                }

                Button {
                    pendingAIMethod = nil
                    showsAIOrientation = true
                } label: {
                    Label("How Radix Uses AI", systemImage: "info.circle")
                }
            }
        } label: {
            HStack(spacing: 5) {
                Image(systemName: "ellipsis.circle")
                Text("Actions")
                Image(systemName: "chevron.down")
                    .font(ResponsiveFont.tinySystem(size: 9, weight: .bold))
            }
            .font(ResponsiveFont.caption2.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.75)
            .frame(minWidth: 82)
        }
        .buttonStyle(.bordered)
        .controlSize(.small)
        .accessibilityLabel("Page actions for \(collection.name)")
        .help("Page Actions")
        .sheet(isPresented: $showsAIOrientation) {
            PageAIOrientationView(
                continuesSelectedAction: pendingAIMethod != nil,
                onContinue: completeAIOrientation,
                onCancel: cancelAIOrientation
            )
        }
    }

    @ViewBuilder
    private func aiMethodButton(
        manualMethod: PendingAIMethod,
        automaticMethod: PendingAIMethod
    ) -> some View {
        Button {
            chooseAIMethod(manualMethod)
        } label: {
            Label("Use Another AI App", systemImage: "doc.on.clipboard")
        }

        Button {
            chooseAIMethod(automaticMethod)
        } label: {
            Label(
                hasGeminiAPIKey ? "Run Automatically in Radix" : "Set Up Gemini API Key…",
                systemImage: hasGeminiAPIKey ? "sparkles" : "key"
            )
        }
    }

    private func chooseAIMethod(_ method: PendingAIMethod) {
        guard RadixRootPreferences.hasSeenPageAIOrientation else {
            pendingAIMethod = method
            showsAIOrientation = true
            return
        }
        run(method)
    }

    private func completeAIOrientation() {
        let method = pendingAIMethod
        RadixRootPreferences.hasSeenPageAIOrientation = true
        pendingAIMethod = nil
        showsAIOrientation = false
        if let method {
            DispatchQueue.main.async {
                run(method)
            }
        }
    }

    private func cancelAIOrientation() {
        pendingAIMethod = nil
        showsAIOrientation = false
    }

    private func run(_ method: PendingAIMethod) {
        switch method {
        case .checkOCRManually: onCheckOCR?()
        case .checkOCRAutomatically: onCheckOCRAutomatically()
        case .extractManually: onManualExtract()
        case .extractAutomatically: onAIExtract()
        case .translateManually: onTranslate()
        case .translateAutomatically: onTranslateAndSave()
        case .quizManually: onCreateQuizManually()
        case .quizAutomatically: onCreateQuizAutomatically()
        }
    }
}

private struct PageAIOrientationView: View {
    let continuesSelectedAction: Bool
    let onContinue: () -> Void
    let onCancel: () -> Void

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 16) {
                        Text("Radix can use AI to check OCR, extract useful phrases, translate a complete page in context, or generate an in-app practice quiz from a saved page.")
                            .font(ResponsiveFont.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

            method(
                icon: "doc.on.clipboard",
                title: "Use Another AI App",
                detail: "Radix prepares the instruction and page evidence for you to copy into ChatGPT, Gemini, or another AI app. No API key is needed, and this option remains available even when automatic AI is configured."
            )

            method(
                icon: "sparkles",
                title: "Run Automatically in Radix",
                detail: "Radix sends the task directly to Gemini and returns the result to the page workflow. This requires a private Gemini API key and depends on Gemini being available."
            )

                        Text("You can edit the underlying OCR, phrase-extraction, translation, and quiz instructions in AI Link.")
                            .font(ResponsiveFont.caption)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(20)
                }

                Divider()

                HStack {
                    Button("Not Now", action: onCancel)
                        .buttonStyle(.bordered)

                    Spacer()

                    Button(continuesSelectedAction ? "Continue" : "Got It", action: onContinue)
                        .buttonStyle(.borderedProminent)
                }
                .padding(20)
            }
            .navigationTitle("Choose How Radix Uses AI")
            .navigationBarTitleDisplayMode(.inline)
        }
        .frame(idealWidth: 440, maxWidth: 520, minHeight: 430, idealHeight: 520)
    }

    private func method(icon: String, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(Color.accentColor)
                .frame(width: 30, height: 30)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 7))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(ResponsiveFont.subheadline.weight(.semibold))
                Text(detail)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

struct SourceCollectionRow: View {
    private static let dateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .short
        return formatter
    }()

    let collection: CharacterCollection
    let isSelected: Bool
    let thumbnail: RadixThumbnail?
    var dateMode: PageCollectionSortOrder = .lastViewed
    let onSelect: () -> Void
    var onDelete: (() -> Void)? = nil

    var body: some View {
        HStack(spacing: 8) {
            Button(action: onSelect) {
                HStack(spacing: 8) {
                    sourceThumbnail

                    VStack(alignment: .leading, spacing: 2) {
                        Text(collection.name)
                            .font(ResponsiveFont.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .lineLimit(1)
                        Text(dateText)
                            .font(ResponsiveFont.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    Text("\(collection.characters.count)")
                        .font(ResponsiveFont.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)

                    if isSelected {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(Color.accentColor)
                            .font(.system(size: 14))
                    }
                }
                .contentShape(Rectangle())
            }
            .buttonStyle(.plain)

            if let onDelete {
                Button(role: .destructive, action: onDelete) {
                    Image(systemName: "trash")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .accessibilityLabel("Delete \(collection.name)")
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .background(isSelected ? Color.accentColor.opacity(0.10) : RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var dateText: String {
        switch dateMode {
        case .lastViewed:
            let date = collection.lastViewedAt ?? collection.createdAt
            return "Viewed \(Self.dateFormatter.string(from: date))"
        case .scanned:
            return "Scanned \(Self.dateFormatter.string(from: collection.createdAt))"
        }
    }

    @ViewBuilder
    private var sourceThumbnail: some View {
        RadixThumbnailView(
            thumbnail: thumbnail,
            size: 34,
            cornerRadius: 6,
            placeholderSystemImage: collection.isFavorite ? "star.fill" : "photo",
            placeholderColor: collection.isFavorite ? Color.yellow : Color.secondary
        )
    }
}

struct SourceMenuRow: View {
    let title: String
    let subtitle: String
    let systemImage: String
    var isSelected = false
    var iconColor: Color = .secondary
    var trailingSystemImage: String?

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: systemImage)
                .font(ResponsiveFont.body)
                .foregroundStyle(iconColor)
                .frame(width: 34, height: 34)
                .background(RadixTheme.background.opacity(0.8))
                .clipShape(RoundedRectangle(cornerRadius: 6))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(ResponsiveFont.body.weight(.semibold))
                    .foregroundStyle(.primary)
                    .lineLimit(1)

                Text(subtitle)
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 4)

            if let trailingSystemImage {
                Image(systemName: trailingSystemImage)
                    .foregroundStyle(Color.accentColor)
                    .font(.system(size: 14))
            }
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 6)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(isSelected ? Color.accentColor.opacity(0.10) : RadixTheme.secondaryBackground.opacity(0.55))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
