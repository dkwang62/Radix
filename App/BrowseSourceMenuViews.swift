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

struct CollectionPageAITask: Identifiable {
    enum Route {
        case manual
        case automatic
    }

    let id: String
    let title: String
    let systemImage: String
    let manualAction: () -> Void
    let automaticAction: () -> Void
}

struct CollectionPageActionsMenu: View {
    private struct PendingAISelection {
        let taskID: String
        let route: CollectionPageAITask.Route
    }

    let collection: CharacterCollection
    let onEdit: () -> Void
    let hasGeminiAPIKey: Bool
    let onChoosePhrases: () -> Void
    let onViewTranslation: () -> Void
    let aiTasks: [CollectionPageAITask]
    @State private var showsAIOrientation = false
    @State private var pendingAISelection: PendingAISelection?

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
                ForEach(aiTasks) { task in
                    Menu {
                        aiMethodButton(for: task)
                    } label: {
                        Label(task.title, systemImage: task.systemImage)
                    }
                }

                Button {
                    pendingAISelection = nil
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
                continuesSelectedAction: pendingAISelection != nil,
                onContinue: completeAIOrientation,
                onCancel: cancelAIOrientation
            )
        }
    }

    @ViewBuilder
    private func aiMethodButton(for task: CollectionPageAITask) -> some View {
        Button {
            chooseAIMethod(taskID: task.id, route: .manual)
        } label: {
            Label("Use Another AI App", systemImage: "doc.on.clipboard")
        }

        Button {
            chooseAIMethod(taskID: task.id, route: .automatic)
        } label: {
            Label(
                hasGeminiAPIKey ? "Run Automatically in Radix" : "Set Up Gemini API Key…",
                systemImage: hasGeminiAPIKey ? "sparkles" : "key"
            )
        }
    }

    private func chooseAIMethod(taskID: String, route: CollectionPageAITask.Route) {
        guard RadixRootPreferences.hasSeenPageAIOrientation else {
            pendingAISelection = PendingAISelection(taskID: taskID, route: route)
            showsAIOrientation = true
            return
        }
        run(taskID: taskID, route: route)
    }

    private func completeAIOrientation() {
        let selection = pendingAISelection
        RadixRootPreferences.hasSeenPageAIOrientation = true
        pendingAISelection = nil
        showsAIOrientation = false
        if let selection {
            DispatchQueue.main.async {
                run(taskID: selection.taskID, route: selection.route)
            }
        }
    }

    private func cancelAIOrientation() {
        pendingAISelection = nil
        showsAIOrientation = false
    }

    private func run(taskID: String, route: CollectionPageAITask.Route) {
        guard let task = aiTasks.first(where: { $0.id == taskID }) else { return }
        switch route {
        case .manual: task.manualAction()
        case .automatic: task.automaticAction()
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
                        Text("Radix can use AI to check OCR, extract useful phrases, translate a complete page in context, generate an in-app practice quiz, or turn a saved page into Conversation Practice sentences.")
                            .font(ResponsiveFont.body)
                            .foregroundStyle(.secondary)
                            .fixedSize(horizontal: false, vertical: true)

                        method(
                            icon: "doc.on.clipboard",
                            title: "Use Another AI App",
                            detail: "Radix prepares the AI prompt and page evidence for you to copy into ChatGPT, Gemini, or another AI app. No API key is needed, and this option remains available even when automatic AI is configured."
                        )

                        method(
                            icon: "sparkles",
                            title: "Run Automatically in Radix",
                            detail: "Radix sends the task directly to Gemini and returns the result to the page workflow. This requires a private Gemini API key and depends on Gemini being available."
                        )

                        Text("You can edit the underlying OCR, phrase-extraction, translation, quiz, and sentence-extraction AI prompts in AI Link.")
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
    var onOpenPractice: (() -> Void)? = nil
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

            if let onOpenPractice {
                Button(action: onOpenPractice) {
                    Image(systemName: "bubble.left.and.bubble.right.fill")
                        .frame(width: 30, height: 30)
                }
                .buttonStyle(.bordered)
                .controlSize(.small)
                .tint(Color.accentColor)
                .accessibilityLabel("Open practice for \(collection.name)")
                .help("Open Page Practice")
            }

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
