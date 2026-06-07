enum RadixCaptureUsage {
    private static let freeScanCountKey = "radixFreeCameraScanCount"
    private static let preferences = RadixPreferences.standard

    static var freeScanCount: Int {
        get {
            preferences.integer(forKey: freeScanCountKey)
        }
        set {
            preferences.set(newValue, forKey: freeScanCountKey)
        }
    }

    @discardableResult
    static func incrementFreeScanCount(limit: Int) -> Int {
        let updatedCount = min(limit, freeScanCount + 1)
        freeScanCount = updatedCount
        return updatedCount
    }
}
