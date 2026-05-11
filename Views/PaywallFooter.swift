import SwiftUI

extension PaywallView {
    var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Button("Restore Purchases") {
                Task { await entitlement.restorePurchases() }
            }
            .buttonStyle(.bordered)

            #if DEBUG
            Toggle("Development Pro Access", isOn: Binding(
                get: { entitlement.debugProOverrideEnabled },
                set: { enabled in
                    entitlement.setDebugProOverride(enabled)
                    if enabled {
                        dismiss()
                    }
                }
            ))
            .toggleStyle(.switch)
            #endif

            if let error = entitlement.lastError, !error.isEmpty {
                Text(error)
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.red)
            }

            Text("Annual renews automatically unless canceled at least 24 hours before renewal.")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}
