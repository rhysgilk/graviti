import Foundation

struct LinkMetadataFetcher {
    private let session: URLSession

    init(session: URLSession? = nil) {
        if let session {
            self.session = session
            return
        }
        let configuration = URLSessionConfiguration.ephemeral
        configuration.timeoutIntervalForRequest = 12
        configuration.timeoutIntervalForResource = 18
        configuration.httpCookieAcceptPolicy = .never
        configuration.urlCache = nil
        self.session = URLSession(configuration: configuration)
    }

    func fetch(_ rawURL: String) async throws -> ArtifactLinkMetadata? {
        guard let url = safeURL(rawURL) else { throw LinkMetadataError.unsafeURL }
        var request = URLRequest(url: url)
        request.cachePolicy = .reloadIgnoringLocalCacheData
        request.setValue("text/html,application/xhtml+xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await session.data(for: request)
        guard let http = response as? HTTPURLResponse,
              (200..<400).contains(http.statusCode),
              let finalURL = safeURL(http.url?.absoluteString ?? rawURL),
              data.count <= 2_000_000,
              http.value(forHTTPHeaderField: "Content-Type")?.lowercased().contains("text/html") == true,
              let html = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) else {
            return nil
        }

        let values = metaValues(in: html)
        let title = clean(values["og:title"] ?? values["twitter:title"] ?? tagContent("title", in: html))
        let summary = clean(values["og:description"] ?? values["twitter:description"] ?? values["description"])
        let siteName = clean(values["og:site_name"]) ?? finalURL.host(percentEncoded: false)?.replacingOccurrences(of: "www.", with: "") ?? "Saved link"
        let imageData = await fetchImage(values["og:image"] ?? values["twitter:image"], relativeTo: finalURL)
        guard title != nil || summary != nil || imageData != nil else { return nil }
        return ArtifactLinkMetadata(
            title: title,
            summary: summary,
            siteName: siteName,
            imageData: imageData,
            resolvedURL: finalURL.absoluteString,
            fetchedAt: .now
        )
    }

    private func fetchImage(_ raw: String?, relativeTo pageURL: URL) async -> Data? {
        guard let raw, let candidate = URL(string: decodeEntities(raw), relativeTo: pageURL)?.absoluteURL,
              let url = safeURL(candidate.absoluteString) else { return nil }
        var request = URLRequest(url: url)
        request.setValue("image/*", forHTTPHeaderField: "Accept")
        guard let (data, response) = try? await session.data(for: request),
              let http = response as? HTTPURLResponse,
              (200..<400).contains(http.statusCode),
              safeURL(http.url?.absoluteString ?? "") != nil,
              http.value(forHTTPHeaderField: "Content-Type")?.lowercased().hasPrefix("image/") == true,
              !data.isEmpty, data.count <= 4_000_000 else { return nil }
        return data
    }

    private func safeURL(_ raw: String) -> URL? {
        guard let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              let host = components.host?.lowercased(), !host.isEmpty,
              !isPrivateHost(host) else { return nil }
        return components.url
    }

    private func isPrivateHost(_ host: String) -> Bool {
        let normalized = host.trimmingCharacters(in: CharacterSet(charactersIn: "[]"))
        if normalized == "localhost" || normalized.hasSuffix(".localhost") || normalized == "0.0.0.0" || normalized == "::1" { return true }
        let parts = normalized.split(separator: ".").compactMap { Int($0) }
        if parts.count == 4 {
            if parts[0] == 10 || parts[0] == 127 { return true }
            if parts[0] == 169, parts[1] == 254 { return true }
            if parts[0] == 172, (16...31).contains(parts[1]) { return true }
            if parts[0] == 192, parts[1] == 168 { return true }
            if parts[0] == 100, (64...127).contains(parts[1]) { return true }
            if parts[0] == 198, (18...19).contains(parts[1]) { return true }
        }
        return ["fc", "fd", "fe8", "fe9", "fea", "feb"].contains { normalized.hasPrefix($0) }
    }

    private func metaValues(in html: String) -> [String: String] {
        let tags = matches(#"<meta\b[^>]*>"#, in: html).compactMap(\.first)
        var values: [String: String] = [:]
        for tag in tags {
            let attributes = Dictionary(uniqueKeysWithValues: matches(#"([\w:-]+)\s*=\s*[\"']([^\"']*)[\"']"#, in: tag, groups: [1, 2]).compactMap { parts in
                parts.count == 2 ? (parts[0].lowercased(), parts[1]) : nil
            })
            guard let key = attributes["property"] ?? attributes["name"],
                  let content = attributes["content"] else { continue }
            values[key.lowercased()] = content
        }
        return values
    }

    private func tagContent(_ tag: String, in html: String) -> String? {
        matches("<\\(tag)\\b[^>]*>(.*?)</\\(tag)>", in: html, groups: [1]).first?.first
    }

    private func matches(_ pattern: String, in text: String, groups: [Int] = [0]) -> [[String]] {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]) else { return [] }
        let range = NSRange(text.startIndex..., in: text)
        return regex.matches(in: text, range: range).map { match in
            groups.compactMap { group in
                guard match.range(at: group).location != NSNotFound,
                      let range = Range(match.range(at: group), in: text) else { return nil }
                return String(text[range])
            }
        }
    }

    private func clean(_ value: String?) -> String? {
        guard let value else { return nil }
        let cleaned = decodeEntities(value)
            .replacingOccurrences(of: #"\s+"#, with: " ", options: .regularExpression)
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : String(cleaned.prefix(1_000))
    }

    private func decodeEntities(_ value: String) -> String {
        value.replacingOccurrences(of: "&amp;", with: "&")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;", with: "'")
            .replacingOccurrences(of: "&lt;", with: "<")
            .replacingOccurrences(of: "&gt;", with: ">")
    }
}

private enum LinkMetadataError: Error {
    case unsafeURL
}
