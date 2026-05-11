import Foundation
import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

func copyToClipboard(_ value: String) {
    #if canImport(UIKit)
    UIPasteboard.general.string = value
    #elseif canImport(AppKit)
    NSPasteboard.general.clearContents()
    NSPasteboard.general.setString(value, forType: .string)
    #endif
}

@MainActor
func showPhraseTable(for character: String, using store: RadixStore) {
    store.preview(character: character, announce: false)
    DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
        NotificationCenter.default.post(name: .radixShowPhraseTable, object: character)
    }
}

func shareAnimation(for character: String) {
    let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isSingleChineseCharacter else {
        return
    }

    Task {
        do {
            let gifURL = try await HanziWriterGIFExporter.export(character: trimmed)
            await presentShareSheet(items: [gifURL])
        } catch {
            debugPrint("Could not create animation for \(trimmed): \(error)")
        }
    }
}

@MainActor
func openAnimationInBrowser(for character: String) {
    guard let url = hostedHanziWriterAnimationURL(for: character) else {
        return
    }

    #if canImport(UIKit)
    UIApplication.shared.open(url)
    #elseif canImport(AppKit)
    NSWorkspace.shared.open(url)
    #endif
}

func copyAnimationPlayerLink(for character: String) {
    guard let url = hostedHanziWriterAnimationURL(for: character) else {
        return
    }
    copyToClipboard(url.absoluteString)
}

func hostedHanziWriterAnimationURL(for character: String) -> URL? {
    let trimmed = character.trimmingCharacters(in: .whitespacesAndNewlines)
    guard trimmed.isSingleChineseCharacter else {
        return nil
    }

    var components = URLComponents(string: "https://dkwang62.github.io/Radix/animate.html")
    components?.queryItems = [
        URLQueryItem(name: "char", value: trimmed)
    ]
    return components?.url
}

extension String {
    var isSingleChineseCharacter: Bool {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count == 1, let scalar = trimmed.unicodeScalars.first else { return false }
        return (0x3400...0x4DBF).contains(scalar.value)
            || (0x2E80...0x2EFF).contains(scalar.value)
            || (0x2F00...0x2FDF).contains(scalar.value)
            || (0x4E00...0x9FFF).contains(scalar.value)
            || (0x20000...0x2EBEF).contains(scalar.value)
    }
}
