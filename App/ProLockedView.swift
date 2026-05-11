import SwiftUI

struct ProLockedView: View {
    let featureName: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26))
                .foregroundStyle(.secondary)
            Text("\(featureName) is a Pro feature")
                .font(.headline)
            Text("Upgrade to unlock this feature and future Pro updates.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button("Upgrade to Pro", action: onUpgrade)
                .buttonStyle(.borderedProminent)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
