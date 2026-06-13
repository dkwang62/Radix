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

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 12) {
                    purchaseLink("Privacy Policy", url: "https://dkwang62.github.io/radix-site/privacy.html")
                    purchaseLink("Terms of Use (EULA)", url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                }
                VStack(alignment: .leading, spacing: 8) {
                    purchaseLink("Privacy Policy", url: "https://dkwang62.github.io/radix-site/privacy.html")
                    purchaseLink("Terms of Use (EULA)", url: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")
                }
            }
            .font(ResponsiveFont.caption.weight(.semibold))
        }
    }

    func purchaseLink(_ title: String, url: String) -> some View {
        Link(destination: URL(string: url)!) {
            Label(title, systemImage: "link")
        }
    }
}
