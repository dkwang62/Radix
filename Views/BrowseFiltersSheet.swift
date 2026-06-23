import SwiftUI

struct BrowseFiltersSheet: View {
    @EnvironmentObject private var store: RadixStore
    let sizeClass: UserInterfaceSizeClass?
    let onClose: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Strokes")
                            .font(ResponsiveFont.caption.bold())
                            .foregroundStyle(.secondary)
                        StrokeRangeSlider(
                            minValue: store.browseFilterBinding(\.strokeMinFilter),
                            maxValue: store.browseFilterBinding(\.strokeMaxFilter)
                        )
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        radicalPicker
                        structurePicker
                    }
                }
                .padding()
            }
            .navigationTitle("Browse Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if BrowseFilterSummary.activeCount(store: store) > 0 {
                        Button("Reset") {
                            store.strokeMinFilter = 0
                            store.selectedRadicalFilter = "none"
                            store.selectedStructureFilter = "none"
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        onClose()
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .presentationDetents(sizeClass == .compact ? [.medium, .large] : [.large])
        }
    }

    private var radicalPicker: some View {
        HStack(spacing: 8) {
            Text("Radical")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Radical", selection: store.browseFilterBinding(\.selectedRadicalFilter)) {
                ForEach(store.availableRadicalFilters, id: \.self) { radical in
                    Text(store.radicalFilterLabel(radical)).tag(radical)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(RadixTheme.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    private var structurePicker: some View {
        HStack(spacing: 8) {
            Text("Structure")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Structure", selection: store.browseFilterBinding(\.selectedStructureFilter)) {
                ForEach(store.availableStructureFilters, id: \.self) { structKey in
                    Text(structKey).tag(structKey)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(RadixTheme.secondaryBackground.opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

enum BrowseFilterSummary {
    @MainActor
    static func activeCount(store: RadixStore) -> Int {
        var count = 0
        if store.strokeMinFilter > 0 { count += 1 }
        if store.selectedRadicalFilter != "none" { count += 1 }
        if store.selectedStructureFilter != "none" { count += 1 }
        return count
    }
}
