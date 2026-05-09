import SwiftUI

#if canImport(UIKit)
import UIKit
#endif

#if canImport(AppKit)
import AppKit
#endif

extension Notification.Name {
    static let radixShowPhraseTable = Notification.Name("radixShowPhraseTable")
}

struct CharacterPreviewHeader: View {
    @EnvironmentObject private var store: RadixStore
    let character: String
    let showClearButton: Bool
    var statusLabel: String? = nil
    var showAddToMemoryButton: Bool = true
    var isVertical: Bool = false
    var onClear: (() -> Void)? = nil
    @State private var showPhraseTableSheet = false
    @State private var variantIndex: Int = 0

    private var usesShortActionLabels: Bool {
        #if targetEnvironment(macCatalyst)
        return isVertical
        #else
        return isVertical || UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    private var isPhone: Bool {
        #if targetEnvironment(macCatalyst)
        return false
        #else
        return UIDevice.current.userInterfaceIdiom == .phone
        #endif
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if let item = store.item(for: character) {
                let allVariants = store.allVariants(for: item.character)
                let counterpart = allVariants.first

                // The currently selected variant (driven by card's cycle button)
                let safeIndex = allVariants.isEmpty ? 0 : variantIndex % allVariants.count
                let activeVariant = allVariants.indices.contains(safeIndex) ? allVariants[safeIndex] : counterpart

                // Determine layout container
                let container = AnyLayout(isVertical ? AnyLayout(VStackLayout(alignment: .leading, spacing: 12)) : AnyLayout(HStackLayout(alignment: .top, spacing: 0)))
                
                container {
                    CharacterPreviewAnimationPanel(
                        item: item,
                        allVariants: allVariants,
                        activeVariant: activeVariant,
                        isVertical: isVertical,
                        onSelectCharacter: selectPreviewCharacter(_:)
                    )
                    .environmentObject(store)

                    CharacterInfoCard(
                        item: item,
                        variants: allVariants.map(\.character),
                        variantIndex: $variantIndex,
                        showClearButton: showClearButton,
                        onShowPhrases: {
                            store.refreshPhrases(for: character)
                            showPhraseTableSheet = true
                        },
                        onClear: onClear,
                        onSelectVariant: { ch in
                            #if targetEnvironment(macCatalyst)
                            store.select(character: ch)
                            store.preview(character: ch)
                            #else
                            if UIDevice.current.userInterfaceIdiom == .phone &&
                                store.route == .search &&
                                store.homeTab == .filter {
                                store.browsePreview(character: ch, preservePhraseContext: true)
                            } else {
                                store.select(character: ch)
                                store.preview(character: ch)
                            }
                            #endif
                        }
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
        }
        .sheet(isPresented: $showPhraseTableSheet) {
            PhraseTableSheet(character: character, isVertical: isVertical)
                .environmentObject(store)
        }
        .onReceive(NotificationCenter.default.publisher(for: .radixShowPhraseTable)) { notification in
            guard let requestedCharacter = notification.object as? String,
                  requestedCharacter == character else { return }
            store.refreshPhrases(for: character)
            showPhraseTableSheet = true
        }
        .onChange(of: character) { _, _ in
            variantIndex = 0
        }
    }

    private func selectPreviewCharacter(_ ch: String) {
        #if targetEnvironment(macCatalyst)
        store.select(character: ch)
        store.preview(character: ch)
        #else
        if UIDevice.current.userInterfaceIdiom == .phone &&
            store.route == .search &&
            store.homeTab == .filter {
            store.browsePreview(character: ch, preservePhraseContext: true)
        } else {
            store.select(character: ch)
            store.preview(character: ch)
        }
        #endif
    }
}
