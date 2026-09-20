import Foundation

struct GoogleSavedCSVRow: Equatable {
    let title: String
    let url: String
    let note: String?
}

struct GoogleSavedCSVResult {
    let rows: [GoogleSavedCSVRow]
    let skippedRows: Int
}

enum GoogleSavedCSVParser {
    static func parse(_ text: String) throws -> GoogleSavedCSVResult {
        let records = try parseRecords(text)
        guard let headerIndex = records.firstIndex(where: { record in
            let names = record.map(normalizedHeader)
            return names.contains("title") &&
                (names.contains("url") || names.contains("item_content_url"))
        }) else {
            throw CSVError.missingHeader
        }

        let headers = records[headerIndex].map(normalizedHeader)
        guard
            let titleIndex = headers.firstIndex(of: "title"),
            let urlIndex = headers.firstIndex(of: "url") ?? headers.firstIndex(of: "item_content_url")
        else {
            throw CSVError.missingHeader
        }
        let noteIndex = headers.firstIndex(of: "note")
        var imported: [GoogleSavedCSVRow] = []
        var skipped = 0

        for record in records.dropFirst(headerIndex + 1) where !record.allSatisfy({ $0.isEmpty }) {
            let title = field(titleIndex, in: record)
            let url = field(urlIndex, in: record)
            let note = noteIndex.map { field($0, in: record) }
            guard !title.isEmpty,
                  let components = URLComponents(string: url),
                  let scheme = components.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  components.host != nil else {
                skipped += 1
                continue
            }
            imported.append(GoogleSavedCSVRow(
                title: title,
                url: url,
                note: note?.isEmpty == true ? nil : note
            ))
        }

        return GoogleSavedCSVResult(rows: imported, skippedRows: skipped)
    }

    private static func field(_ index: Int, in record: [String]) -> String {
        guard record.indices.contains(index) else { return "" }
        return record[index].trimmingCharacters(in: .whitespacesAndNewlines)
    }

    nonisolated private static func normalizedHeader(_ raw: String) -> String {
        raw.trimmingCharacters(in: .whitespacesAndNewlines)
            .replacingOccurrences(of: "\u{FEFF}", with: "")
            .lowercased()
    }

    private static func parseRecords(_ text: String) throws -> [[String]] {
        let characters = Array(text.replacingOccurrences(of: "\r\n", with: "\n")
            .replacingOccurrences(of: "\r", with: "\n"))
        var records: [[String]] = []
        var record: [String] = []
        var field = ""
        var quoted = false
        var index = 0

        while index < characters.count {
            let character = characters[index]
            switch character {
            case "\"":
                if quoted && index + 1 < characters.count && characters[index + 1] == "\"" {
                    field.append("\"")
                    index += 1
                } else {
                    quoted.toggle()
                }
            case "," where !quoted:
                record.append(field)
                field = ""
            case "\n" where !quoted:
                record.append(field)
                records.append(record)
                record = []
                field = ""
            default:
                field.append(character)
            }
            index += 1
        }

        guard !quoted else { throw CSVError.unclosedQuote }
        if !record.isEmpty || !field.isEmpty {
            record.append(field)
            records.append(record)
        }
        return records
    }
}

private enum CSVError: LocalizedError {
    case missingHeader
    case unclosedQuote

    var errorDescription: String? {
        switch self {
        case .missingHeader: String(localized: "This CSV needs Title and URL columns from Google Saved.")
        case .unclosedQuote: String(localized: "This CSV has an unfinished quoted field.")
        }
    }
}
