import SwiftUI

extension ComponentsExplorerShell {
    var activeRootFilterCount: Int {
        var count = 0
        if store.rootMinStroke > 0 || store.rootMaxStroke < 30 { count += 1 }
        if store.rootRadicalFilter != "none" { count += 1 }
        if store.rootStructureFilter != "none" { count += 1 }
        return count
    }

    var rootFilterButtonTitle: String {
        activeRootFilterCount > 0 ? "Filters (\(activeRootFilterCount))" : "Filters"
    }

    var rootFiltersSheet: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 18) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Minimum Strokes")
                            .font(ResponsiveFont.caption.bold())
                            .foregroundStyle(.secondary)
                        StrokeRangeSlider(minValue: $store.rootMinStroke, maxValue: $store.rootMaxStroke)
                    }

                    VStack(alignment: .leading, spacing: 10) {
                        rootRadicalPicker
                        rootStructurePicker
                    }
                }
                .padding()
            }
            .navigationTitle("Component Filters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    if activeRootFilterCount > 0 {
                        Button("Reset") {
                            store.rootMinStroke = 0
                            store.rootMaxStroke = 30
                            store.rootRadicalFilter = "none"
                            store.rootStructureFilter = "none"
                        }
                    }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showRootFilters = false
                    } label: {
                        Image(systemName: "xmark")
                    }
                    .accessibilityLabel("Close")
                }
            }
            .presentationDetents(sizeClass == .compact ? [.medium, .large] : [.large])
        }
    }

    var rootRadicalPicker: some View {
        HStack(spacing: 8) {
            Text("Radical")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Radical", selection: $store.rootRadicalFilter) {
                ForEach(store.availableRadicalFilters, id: \.self) { radical in
                    Text(store.radicalFilterLabel(radical)).tag(radical)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
            .frame(minWidth: 80)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }

    var rootStructurePicker: some View {
        HStack(spacing: 8) {
            Text("Structure")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
            Picker("Structure", selection: $store.rootStructureFilter) {
                ForEach(store.availableStructureFilters, id: \.self) { structKey in
                    Text(structKey).tag(structKey)
                }
            }
            .font(ResponsiveFont.body)
            .pickerStyle(.menu)
        }
        .padding(.horizontal, 8)
        .background(Color(.secondarySystemBackground).opacity(0.5))
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}
