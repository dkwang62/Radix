import SwiftUI

struct StrokeRangeSlider: View {
    @Binding var minValue: Int
    @Binding var maxValue: Int
    private let lowerBound = 0
    private let upperBound = 30

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Min: \(minValue) strokes")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                Text("Max: \(upperBound) strokes")
                    .font(ResponsiveFont.caption)
                    .foregroundStyle(.secondary)
            }
            Slider(
                value: Binding(
                    get: { Double(minValue) },
                    set: { newValue in
                        let newMin = Int(newValue.rounded())
                        minValue = min(max(newMin, lowerBound), min(maxValue, upperBound))
                    }
                ),
                in: Double(lowerBound)...Double(upperBound),
                step: 1
            )
        }
        .onAppear { maxValue = upperBound }
        .onChange(of: minValue) { _, _ in maxValue = upperBound }
    }
}
