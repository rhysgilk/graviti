import Foundation

struct AppleMapsGuide {
    let title: String
    let placeIdentifiers: [String]
}

enum AppleMapsGuideParser {
    static func parse(_ rawURL: String) throws -> AppleMapsGuide {
        guard let components = URLComponents(string: rawURL),
              components.host?.lowercased() == "maps.apple.com",
              components.path == "/guides",
              let encoded = components.queryItems?.first(where: { $0.name == "user" })?.value,
              encoded.count <= 100_000,
              let data = Data(base64Encoded: encoded) else {
            throw AppleMapsGuideError.unreadable
        }

        var reader = WireReader(data: data)
        var title: String?
        var identifiers: [String] = []
        while let field = try reader.next() {
            switch (field.number, field.value) {
            case (1, .bytes(let value)):
                title = String(data: value, encoding: .utf8)
            case (2, .bytes(let value)):
                var place = WireReader(data: value)
                var namespace: UInt64?
                var identifier: UInt64?
                while let part = try place.next() {
                    switch (part.number, part.value) {
                    case (1, .integer(let value)): namespace = value
                    case (2, .integer(let value)): identifier = value
                    default: break
                    }
                }
                // Shared Apple Maps guides use namespace 9902 for map items.
                if namespace == 9902, let identifier, identifier != 0 {
                    identifiers.append(String(format: "I%016llX", identifier))
                }
            default: break
            }
            guard identifiers.count <= 500 else { throw AppleMapsGuideError.unreadable }
        }

        var seen = Set<String>()
        let uniqueIdentifiers = identifiers.filter { seen.insert($0).inserted }
        guard let title = title?.trimmingCharacters(in: .whitespacesAndNewlines),
              !title.isEmpty, title.count <= 200,
              !uniqueIdentifiers.isEmpty else {
            throw AppleMapsGuideError.unreadable
        }
        return AppleMapsGuide(title: title, placeIdentifiers: uniqueIdentifiers)
    }
}

enum AppleMapsGuideError: LocalizedError {
    case unreadable

    var errorDescription: String? {
        "This Apple Maps guide could not be read. Its link is still saved in your Library."
    }
}

private struct WireReader {
    enum Value {
        case integer(UInt64)
        case bytes(Data)
    }

    struct Field {
        let number: UInt64
        let value: Value
    }

    private let data: Data
    private var index = 0

    init(data: Data) { self.data = data }

    mutating func next() throws -> Field? {
        guard index < data.count else { return nil }
        let tag = try readInteger()
        let number = tag >> 3
        guard number != 0 else { throw AppleMapsGuideError.unreadable }
        switch tag & 7 {
        case 0:
            return Field(number: number, value: .integer(try readInteger()))
        case 1:
            return Field(number: number, value: .bytes(try readBytes(count: 8)))
        case 2:
            let length = try readInteger()
            guard length <= UInt64(data.count - index) else { throw AppleMapsGuideError.unreadable }
            return Field(number: number, value: .bytes(try readBytes(count: Int(length))))
        case 5:
            return Field(number: number, value: .bytes(try readBytes(count: 4)))
        default:
            throw AppleMapsGuideError.unreadable
        }
    }

    private mutating func readInteger() throws -> UInt64 {
        var value: UInt64 = 0
        for offset in 0..<10 {
            guard index < data.count else { throw AppleMapsGuideError.unreadable }
            let byte = data[index]
            index += 1
            if offset == 9 && byte > 1 { throw AppleMapsGuideError.unreadable }
            value |= UInt64(byte & 0x7f) << (offset * 7)
            if byte & 0x80 == 0 { return value }
        }
        throw AppleMapsGuideError.unreadable
    }

    private mutating func readBytes(count: Int) throws -> Data {
        guard count >= 0, count <= data.count - index else { throw AppleMapsGuideError.unreadable }
        defer { index += count }
        return data.subdata(in: index..<(index + count))
    }
}
