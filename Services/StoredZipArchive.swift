import Foundation

struct DataExportZipEntry {
    let path: String
    let data: Data
}

enum StoredZipArchive {
    static func makeData(entries: [DataExportZipEntry], timestamp: Date = Date()) throws -> Data {
        var archive = Data()
        var centralDirectory = Data()
        let dosTimeDate = dosTimeDate(for: timestamp)

        for entry in entries {
            guard let nameData = entry.path.data(using: .utf8) else {
                throw NSError(domain: "Radix", code: 2031, userInfo: [NSLocalizedDescriptionKey: "Invalid ZIP entry name: \(entry.path)"])
            }
            let offset = UInt32(archive.count)
            let crc = CRC32.checksum(entry.data)
            let size = UInt32(entry.data.count)

            archive.appendLittleEndian(UInt32(0x04034b50))
            archive.appendLittleEndian(UInt16(20))
            archive.appendLittleEndian(UInt16(0x0800))
            archive.appendLittleEndian(UInt16(0))
            archive.appendLittleEndian(dosTimeDate.time)
            archive.appendLittleEndian(dosTimeDate.date)
            archive.appendLittleEndian(crc)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(size)
            archive.appendLittleEndian(UInt16(nameData.count))
            archive.appendLittleEndian(UInt16(0))
            archive.append(nameData)
            archive.append(entry.data)

            centralDirectory.appendLittleEndian(UInt32(0x02014b50))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(20))
            centralDirectory.appendLittleEndian(UInt16(0x0800))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(dosTimeDate.time)
            centralDirectory.appendLittleEndian(dosTimeDate.date)
            centralDirectory.appendLittleEndian(crc)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(size)
            centralDirectory.appendLittleEndian(UInt16(nameData.count))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt16(0))
            centralDirectory.appendLittleEndian(UInt32(0))
            centralDirectory.appendLittleEndian(offset)
            centralDirectory.append(nameData)
        }

        let centralDirectoryOffset = UInt32(archive.count)
        archive.append(centralDirectory)
        archive.appendLittleEndian(UInt32(0x06054b50))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(0))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt16(entries.count))
        archive.appendLittleEndian(UInt32(centralDirectory.count))
        archive.appendLittleEndian(centralDirectoryOffset)
        archive.appendLittleEndian(UInt16(0))
        return archive
    }

    static func entriesByPath(in data: Data) throws -> [String: Data] {
        var entries: [String: Data] = [:]
        var offset = 0

        while offset + 4 <= data.count {
            let signature = try data.littleEndianUInt32(at: offset)
            if signature == 0x02014b50 || signature == 0x06054b50 {
                break
            }
            guard signature == 0x04034b50 else {
                throw NSError(domain: "RadixZip", code: 2101, userInfo: [NSLocalizedDescriptionKey: "This ZIP archive is not in a supported backup format."])
            }
            guard offset + 30 <= data.count else {
                throw NSError(domain: "RadixZip", code: 2102, userInfo: [NSLocalizedDescriptionKey: "This ZIP archive is incomplete."])
            }

            let flags = try data.littleEndianUInt16(at: offset + 6)
            let compressionMethod = try data.littleEndianUInt16(at: offset + 8)
            let compressedSize = Int(try data.littleEndianUInt32(at: offset + 18))
            let uncompressedSize = Int(try data.littleEndianUInt32(at: offset + 22))
            let nameLength = Int(try data.littleEndianUInt16(at: offset + 26))
            let extraLength = Int(try data.littleEndianUInt16(at: offset + 28))

            guard compressionMethod == 0 else {
                throw NSError(domain: "RadixZip", code: 2103, userInfo: [NSLocalizedDescriptionKey: "This backup ZIP uses compression Radix cannot restore yet."])
            }
            guard flags & 0x0008 == 0 else {
                throw NSError(domain: "RadixZip", code: 2104, userInfo: [NSLocalizedDescriptionKey: "This backup ZIP uses streaming descriptors Radix cannot restore yet."])
            }
            guard compressedSize == uncompressedSize else {
                throw NSError(domain: "RadixZip", code: 2105, userInfo: [NSLocalizedDescriptionKey: "This backup ZIP entry has inconsistent sizes."])
            }

            let nameStart = offset + 30
            let dataStart = nameStart + nameLength + extraLength
            let dataEnd = dataStart + compressedSize
            guard nameStart <= data.count, dataStart <= data.count, dataEnd <= data.count else {
                throw NSError(domain: "RadixZip", code: 2106, userInfo: [NSLocalizedDescriptionKey: "This backup ZIP entry is incomplete."])
            }
            guard let path = String(data: data[nameStart..<nameStart + nameLength], encoding: .utf8) else {
                throw NSError(domain: "RadixZip", code: 2107, userInfo: [NSLocalizedDescriptionKey: "This backup ZIP contains an invalid filename."])
            }

            entries[path] = Data(data[dataStart..<dataEnd])
            offset = dataEnd
        }

        return entries
    }

    private static func dosTimeDate(for date: Date) -> (time: UInt16, date: UInt16) {
        let components = Calendar.current.dateComponents([.year, .month, .day, .hour, .minute, .second], from: date)
        let year = max((components.year ?? 1980), 1980) - 1980
        let month = components.month ?? 1
        let day = components.day ?? 1
        let hour = components.hour ?? 0
        let minute = components.minute ?? 0
        let second = (components.second ?? 0) / 2

        let dosTime = UInt16((hour << 11) | (minute << 5) | second)
        let dosDate = UInt16((year << 9) | (month << 5) | day)
        return (dosTime, dosDate)
    }
}

private enum CRC32 {
    private static let table: [UInt32] = (0..<256).map { value in
        var crc = UInt32(value)
        for _ in 0..<8 {
            if crc & 1 == 1 {
                crc = (crc >> 1) ^ 0xedb88320
            } else {
                crc >>= 1
            }
        }
        return crc
    }

    static func checksum(_ data: Data) -> UInt32 {
        var crc: UInt32 = 0xffffffff
        for byte in data {
            let index = Int((crc ^ UInt32(byte)) & 0xff)
            crc = (crc >> 8) ^ table[index]
        }
        return crc ^ 0xffffffff
    }
}

private extension Data {
    mutating func appendLittleEndian(_ value: UInt16) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    mutating func appendLittleEndian(_ value: UInt32) {
        var littleEndian = value.littleEndian
        Swift.withUnsafeBytes(of: &littleEndian) { append(contentsOf: $0) }
    }

    func littleEndianUInt16(at offset: Int) throws -> UInt16 {
        guard offset >= 0, offset + 2 <= count else {
            throw NSError(domain: "RadixZip", code: 2110, userInfo: [NSLocalizedDescriptionKey: "This ZIP archive is truncated."])
        }
        return self[offset..<offset + 2].enumerated().reduce(UInt16(0)) { value, pair in
            value | (UInt16(pair.element) << UInt16(pair.offset * 8))
        }
    }

    func littleEndianUInt32(at offset: Int) throws -> UInt32 {
        guard offset >= 0, offset + 4 <= count else {
            throw NSError(domain: "RadixZip", code: 2111, userInfo: [NSLocalizedDescriptionKey: "This ZIP archive is truncated."])
        }
        return self[offset..<offset + 4].enumerated().reduce(UInt32(0)) { value, pair in
            value | (UInt32(pair.element) << UInt32(pair.offset * 8))
        }
    }
}
