import SwiftUI

extension RootView {
    func exportProfile() {
        if entitlement.requiresPro(.myBackup) {
            presentPaywall(for: .myBackup)
            return
        }
        do {
            profileExportDocument = JSONFileDocument(data: try store.exportProfileData())
            showProfileExporter = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    func importProfile() {
        if entitlement.requiresPro(.myBackup) {
            presentPaywall(for: .myBackup)
            return
        }
        showProfileImporter = true
    }

    func loadAddPhrases() {
        if entitlement.requiresPro(.advanced) {
            presentPaywall(for: .advanced)
            return
        }
        showAddPhrasesImporter = true
    }

    func exportAddPhrases() {
        if entitlement.requiresPro(.advanced) {
            presentPaywall(for: .advanced)
            return
        }
        do {
            addPhrasesExportDocument = AddPhrasesFileDocument(data: try store.exportAddPhrasesDB())
            showAddPhrasesExporter = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    func useDefaultAddPhrases() {
        if entitlement.requiresPro(.advanced) {
            presentPaywall(for: .advanced)
            return
        }
        do {
            try store.restoreDefaultAddPhrasesFile()
            importExportMessage = "Using the default phrases_add.db file."
            showImportExportAlert = true
        } catch {
            importExportError = error.localizedDescription
        }
    }

    func presentPaywall(for gate: EntitlementManager.FeatureGate) {
        store.showPaywall(for: gate)
    }
}
