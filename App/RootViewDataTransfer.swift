import SwiftUI

extension RootView {
    func exportProfile() {
        if entitlement.requiresPro(.profileTransfer) {
            presentPaywall(for: .profileTransfer)
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
        if entitlement.requiresPro(.profileTransfer) {
            presentPaywall(for: .profileTransfer)
            return
        }
        showProfileImporter = true
    }

    func loadAddPhrases() {
        if entitlement.requiresPro(.dataEdit) {
            presentPaywall(for: .dataEdit)
            return
        }
        showAddPhrasesImporter = true
    }

    func exportAddPhrases() {
        if entitlement.requiresPro(.dataEdit) {
            presentPaywall(for: .dataEdit)
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
        if entitlement.requiresPro(.dataEdit) {
            presentPaywall(for: .dataEdit)
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
