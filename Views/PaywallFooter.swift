import SwiftUI

extension PaywallView {
    var footerSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 10) {
                Button {
                    Task { await entitlement.restorePurchases() }
                } label: {
                    Label("Restore Purchases", systemImage: "arrow.clockwise")
                }
                .buttonStyle(.bordered)

                Spacer(minLength: 0)
            }

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
                Label(error, systemImage: "exclamationmark.triangle")
                    .font(ResponsiveFont.footnote)
                    .foregroundStyle(.red)
                    .padding(10)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .background(Color.red.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 8))
            }

            Label("The first 100 Camera or Text pages are free. Saved items, Browse, Search, Study, AI Link, and editing stay available; Radix Plus is for unlimited pages, import tools, snapshots, and backup.", systemImage: "info.circle")
                .font(ResponsiveFont.caption)
                .foregroundStyle(.secondary)
        }
    }
}
