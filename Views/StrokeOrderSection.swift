import SwiftUI

enum StrokeAnimationToken {
    static func stable(for key: String) -> UUID {
        var hash: UInt64 = 1_469_598_103_934_665_603
        for byte in key.utf8 {
            hash ^= UInt64(byte)
            hash &*= 1_099_511_628_211
        }

        let suffixValue = hash & 0x0000_FFFF_FFFF_FFFF
        let suffix = String(suffixValue, radix: 16)
        let paddedSuffix = String(repeating: "0", count: max(0, 12 - suffix.count)) + suffix
        return UUID(uuidString: "00000000-0000-4000-8000-\(paddedSuffix)") ?? UUID()
    }
}

struct StrokeAnimationHeaderLabel: View {
    let text: String

    var body: some View {
        Text(text.isEmpty ? " " : text)
            .font(ResponsiveFont.tinySystem(size: 11, weight: .semibold))
            .foregroundStyle(.primary)
            .lineLimit(1)
            .minimumScaleFactor(0.75)
    }
}

struct CharacterReadAloudButton: View {
    @EnvironmentObject private var store: RadixStore
    let character: String

    var body: some View {
        Button {
            store.speakCharacter(character)
        } label: {
            Image(systemName: "speaker.wave.2")
                .font(ResponsiveFont.tinySystem(size: 11, weight: .semibold))
                .foregroundStyle(RadixAccent.primary)
                .radixIconButtonSurface(size: 26)
        }
        .buttonStyle(.plain)
        .radixMinimumTapTarget()
        .accessibilityLabel("Read \(character) aloud")
        .help("Read \(character) aloud")
    }
}
