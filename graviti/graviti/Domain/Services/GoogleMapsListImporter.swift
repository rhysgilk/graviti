import Foundation

struct GoogleMapsList {
    let title: String
    let places: [GoogleMapsListPlace]
}

struct GoogleMapsListPlace: Equatable {
    let title: String
    let address: String?
    let note: String?
    let latitude: Double?
    let longitude: Double?
    let featureIdentifiers: [String]

    var sourceURL: String {
        if featureIdentifiers.count >= 2,
           let first = Self.hexIdentifier(featureIdentifiers[0]),
           let second = Self.hexIdentifier(featureIdentifiers[1]) {
            var components = URLComponents()
            components.scheme = "https"
            components.host = "www.google.com"
            components.path = "/maps/place/\(title)/data=!4m2!3m1!1s0x\(first):0x\(second)"
            if let url = components.url?.absoluteString { return url }
        }

        var components = URLComponents()
        components.scheme = "https"
        components.host = "www.google.com"
        components.path = "/maps/search/"
        let query = [title, address]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: ", ")
        components.queryItems = [
            URLQueryItem(name: "api", value: "1"),
            URLQueryItem(name: "query", value: query)
        ]
        return components.url?.absoluteString ?? "https://www.google.com/maps"
    }

    private static func hexIdentifier(_ value: String) -> String? {
        if let signed = Int64(value) {
            return String(UInt64(bitPattern: signed), radix: 16)
        }
        if let unsigned = UInt64(value) {
            return String(unsigned, radix: 16)
        }
        return nil
    }
}

enum GoogleMapsListParser {
    static func dataEndpoint(in pageData: Data, relativeTo pageURL: URL) throws -> URL {
        guard pageData.count <= 3_000_000,
              let page = String(data: pageData, encoding: .utf8)
                ?? String(data: pageData, encoding: .isoLatin1),
              let marker = page.range(of: "entitylist/getlist?"),
              let hrefStart = page[..<marker.lowerBound].range(of: "href=\"", options: .backwards),
              let hrefEnd = page[marker.lowerBound...].firstIndex(of: "\"") else {
            throw GoogleMapsListError.unreadable
        }

        let start = hrefStart.upperBound
        let encodedHref = String(page[start..<hrefEnd])
        let href = encodedHref
            .replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&#38;", with: "&")
        guard let endpoint = URL(string: href, relativeTo: pageURL)?.absoluteURL,
              endpoint.scheme?.lowercased() == "https",
              isGoogleHost(endpoint.host),
              endpoint.path == "/maps/preview/entitylist/getlist" else {
            throw GoogleMapsListError.unreadable
        }
        return endpoint
    }

    static func parse(_ data: Data) throws -> GoogleMapsList {
        guard data.count <= 6_000_000,
              var payload = String(data: data, encoding: .utf8) else {
            throw GoogleMapsListError.unreadable
        }
        if payload.hasPrefix(")]}'") {
            guard let newline = payload.firstIndex(of: "\n") else {
                throw GoogleMapsListError.unreadable
            }
            payload = String(payload[payload.index(after: newline)...])
        }

        guard let root = try JSONSerialization.jsonObject(with: Data(payload.utf8)) as? [Any],
              let list = root[safe: 0] as? [Any],
              let title = clean(list[safe: 4] as? String),
              let rawPlaces = list[safe: 8] as? [Any],
              rawPlaces.count <= 500 else {
            throw GoogleMapsListError.unreadable
        }

        var places = [GoogleMapsListPlace]()
        var seenURLs = Set<String>()
        for rawPlace in rawPlaces {
            guard let row = rawPlace as? [Any],
                  let name = clean(row[safe: 2] as? String) else { continue }
            let details = row[safe: 1] as? [Any]
            let coordinate = details?[safe: 5] as? [Any]
            let identifiers = (details?[safe: 6] as? [Any])?.compactMap { $0 as? String } ?? []
            let place = GoogleMapsListPlace(
                title: name,
                address: clean(details?[safe: 4] as? String),
                note: clean(row[safe: 3] as? String),
                latitude: number(coordinate?[safe: 2]),
                longitude: number(coordinate?[safe: 3]),
                featureIdentifiers: identifiers
            )
            guard seenURLs.insert(place.sourceURL).inserted else { continue }
            places.append(place)
        }
        guard !places.isEmpty else { throw GoogleMapsListError.empty }
        return GoogleMapsList(title: title, places: places)
    }

    private static func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = value
            .replacingOccurrences(of: "\n", with: " ")
            .split(whereSeparator: \.isWhitespace)
            .joined(separator: " ")
        return cleaned.isEmpty ? nil : cleaned
    }

    private static func number(_ value: Any?) -> Double? {
        (value as? NSNumber)?.doubleValue
    }

    private static func isGoogleHost(_ host: String?) -> Bool {
        guard let host = host?.lowercased() else { return false }
        return host == "google.com" || host.hasSuffix(".google.com")
    }
}

enum GoogleMapsListImporter {
    static func load(_ rawURL: String, session: URLSession = .shared) async throws -> GoogleMapsList {
        guard MapLinkMetadata.provider(for: rawURL) == .google,
              let url = URL(string: rawURL) else {
            throw GoogleMapsListError.notAList
        }

        var pageRequest = URLRequest(url: url)
        pageRequest.timeoutInterval = 20
        pageRequest.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (pageData, pageResponse) = try await session.data(for: pageRequest)
        guard let pageHTTP = pageResponse as? HTTPURLResponse,
              (200..<300).contains(pageHTTP.statusCode),
              let pageURL = pageHTTP.url,
              MapLinkMetadata.provider(for: pageURL.absoluteString) == .google else {
            throw GoogleMapsListError.notAList
        }

        let endpoint: URL
        do {
            endpoint = try GoogleMapsListParser.dataEndpoint(in: pageData, relativeTo: pageURL)
        } catch {
            throw GoogleMapsListError.notAList
        }
        var listRequest = URLRequest(url: endpoint)
        listRequest.timeoutInterval = 20
        listRequest.setValue("en-US,en;q=0.9", forHTTPHeaderField: "Accept-Language")
        let (listData, listResponse) = try await session.data(for: listRequest)
        guard let listHTTP = listResponse as? HTTPURLResponse,
              (200..<300).contains(listHTTP.statusCode) else {
            throw GoogleMapsListError.unavailable
        }
        return try GoogleMapsListParser.parse(listData)
    }
}

enum GoogleMapsListError: LocalizedError {
    case notAList
    case unavailable
    case unreadable
    case empty

    var errorDescription: String? {
        switch self {
        case .notAList:
            String(localized: "This Google Maps link isn't a shared list.")
        case .unavailable:
            String(localized: "This Google Maps list is unavailable. Check that link sharing is enabled and try again.")
        case .unreadable:
            String(localized: "This Google Maps list couldn't be read. Google may have changed its shared-list format.")
        case .empty:
            String(localized: "This Google Maps list doesn't contain any places Graviti can import.")
        }
    }
}

private extension Array {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
