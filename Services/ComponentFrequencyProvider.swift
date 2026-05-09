import Foundation

struct ComponentFrequencyProvider {
    private var cachedSubtlexFrequencies: [String: Double]?

    mutating func subtlexFrequencies() -> [String: Double] {
        if let cachedSubtlexFrequencies {
            return cachedSubtlexFrequencies
        }

        if let jsonURL = locateSubtlexJSONURL(),
           let data = try? Data(contentsOf: jsonURL),
           let parsed = try? JSONDecoder().decode([String: Double].self, from: data),
           !parsed.isEmpty {
            cachedSubtlexFrequencies = parsed
            return parsed
        }

        guard let url = locateSubtlexFileURL(),
              let data = try? Data(contentsOf: url) else {
            cachedSubtlexFrequencies = [:]
            return [:]
        }

        let gb18030 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_18030_2000.rawValue)))
        let gb2312 = String.Encoding(rawValue: CFStringConvertEncodingToNSStringEncoding(CFStringEncoding(CFStringEncodings.GB_2312_80.rawValue)))
        let content =
            String(data: data, encoding: gb18030) ??
            String(data: data, encoding: gb2312) ??
            String(data: data, encoding: .utf8) ??
            String(decoding: data, as: UTF8.self)
        if content.isEmpty {
            cachedSubtlexFrequencies = [:]
            return [:]
        }

        var out: [String: Double] = [:]
        for line in content.split(separator: "\n") {
            if line.hasPrefix("Character") || line.hasPrefix("Total") {
                continue
            }
            let parts = line.split(separator: "\t")
            guard parts.count >= 3 else { continue }
            let char = String(parts[0]).trimmingCharacters(in: .whitespacesAndNewlines)
            let freq = Double(parts[2]) ?? 0
            if char.count == 1, freq > 0 {
                out[char] = freq
            }
        }
        cachedSubtlexFrequencies = out
        return out
    }

    private func locateSubtlexFileURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "SUBTLEX-CH-CHR", withExtension: "txt") {
            return direct
        }
        if let txts = Bundle.main.urls(forResourcesWithExtension: "txt", subdirectory: nil),
           let match = txts.first(where: { $0.lastPathComponent.uppercased().contains("SUBTLEX") }) {
            return match
        }
        if let all = Bundle.main.urls(forResourcesWithExtension: nil, subdirectory: nil),
           let match = all.first(where: { $0.lastPathComponent.uppercased().contains("SUBTLEX-CH-CHR") }) {
            return match
        }
        return nil
    }

    private func locateSubtlexJSONURL() -> URL? {
        if let direct = Bundle.main.url(forResource: "subtlex_freq", withExtension: "json") {
            return direct
        }
        if let inResources = Bundle.main.url(forResource: "subtlex_freq", withExtension: "json", subdirectory: "Resources") {
            return inResources
        }
        if let jsons = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: nil),
           let match = jsons.first(where: { $0.lastPathComponent.lowercased().contains("subtlex_freq") }) {
            return match
        }
        if let jsonsInResources = Bundle.main.urls(forResourcesWithExtension: "json", subdirectory: "Resources"),
           let match = jsonsInResources.first(where: { $0.lastPathComponent.lowercased().contains("subtlex_freq") }) {
            return match
        }
        let fileManager = FileManager.default
        if let enumerator = fileManager.enumerator(at: Bundle.main.bundleURL, includingPropertiesForKeys: nil) {
            for case let fileURL as URL in enumerator where fileURL.lastPathComponent.lowercased() == "subtlex_freq.json" {
                return fileURL
            }
        }
        return nil
    }
}
