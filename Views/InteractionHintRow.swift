import SwiftUI

struct InteractionHintRow: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase

    let previewText: String
    let memoryText: String
    let copyText: String

    @State private var hasAnimatedInteractionHintRow = RadixInteractionPreferences.hasAnimatedHintRow
    @State private var isPulsing = false
    @State private var pulseTask: Task<Void, Never>?

    var body: some View {
        HStack(spacing: 0) {
            hintSegment(icon: "cursorarrow", text: previewText)
            segmentDivider
            hintSegment(icon: "bookmark", text: memoryText)
            segmentDivider
            hintSegment(icon: "doc.on.doc", text: copyText)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(RadixTheme.secondaryBackground)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isPulsing ? Color.accentColor.opacity(0.26) : Color.primary.opacity(0.06),
                    lineWidth: 1
                )
        )
        .scaleEffect(isPulsing ? 1.025 : 1.0)
        .shadow(color: Color.accentColor.opacity(isPulsing ? 0.16 : 0), radius: 8)
        .onAppear {
            hasAnimatedInteractionHintRow = RadixInteractionPreferences.hasAnimatedHintRow
            schedulePulseIfNeeded()
        }
        .onChange(of: scenePhase) { _, newPhase in
            if newPhase == .active {
                schedulePulseIfNeeded()
            } else {
                cancelPulse()
            }
        }
        .onDisappear {
            cancelPulse()
        }
    }

    private func hintSegment(icon: String, text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: 6) {
            Image(systemName: icon)
                .font(ResponsiveFont.tinySystem(size: 11, weight: .semibold))
                .foregroundStyle(Color.accentColor.opacity(0.9))
                .frame(width: 14, alignment: .center)

            Text(text)
                .foregroundStyle(Color.primary.opacity(0.72))
        }
        .font(ResponsiveFont.caption)
        .frame(maxWidth: .infinity, alignment: .leading)
        .multilineTextAlignment(.leading)
        .fixedSize(horizontal: false, vertical: true)
    }

    private var segmentDivider: some View {
        Rectangle()
            .fill(Color.primary.opacity(0.08))
            .frame(width: 1)
            .padding(.horizontal, 10)
            .padding(.vertical, 2)
    }

    private func schedulePulseIfNeeded() {
        guard scenePhase == .active else { return }
        guard !hasAnimatedInteractionHintRow else { return }
        guard pulseTask == nil else { return }

        pulseTask = Task {
            try? await Task.sleep(for: .milliseconds(700))
            guard !Task.isCancelled else { return }

            hasAnimatedInteractionHintRow = true
            RadixInteractionPreferences.hasAnimatedHintRow = true

            guard !reduceMotion else {
                pulseTask = nil
                return
            }

            await MainActor.run {
                runPulseSequence()
            }

            try? await Task.sleep(for: .milliseconds(3000))
            guard !Task.isCancelled else { return }

            await MainActor.run {
                pulseTask = nil
            }
        }
    }

    private func cancelPulse() {
        pulseTask?.cancel()
        pulseTask = nil
        isPulsing = false
    }

    @MainActor
    private func runPulseSequence() {
        Task { @MainActor in
            for cycle in 0..<3 {
                withAnimation(.easeInOut(duration: 0.30)) {
                    isPulsing = true
                }

                try? await Task.sleep(for: .milliseconds(320))
                withAnimation(.easeInOut(duration: 0.26)) {
                    isPulsing = false
                }

                if cycle < 2 {
                    try? await Task.sleep(for: .milliseconds(300))
                }
            }
        }
    }
}
