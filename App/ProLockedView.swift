import SwiftUI

struct ProLockedView: View {
    let featureName: String
    let onUpgrade: () -> Void

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "lock.fill")
                .font(.system(size: 26))
                .foregroundStyle(Color.accentColor)
                .frame(width: 48, height: 48)
                .background(Color.accentColor.opacity(0.12))
                .clipShape(RoundedRectangle(cornerRadius: 8))
            Text("\(featureName) is locked")
                .font(.headline)
            Text("You can preview this area for free. Unlock only when you need to use it.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
            Button {
                onUpgrade()
            } label: {
                Label("View Upgrade", systemImage: "sparkles")
            }
                .buttonStyle(.borderedProminent)
                .padding(.top, 4)
        }
        .padding(20)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
    }
}
