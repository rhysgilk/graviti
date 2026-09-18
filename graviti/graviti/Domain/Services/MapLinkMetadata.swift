import Foundation

enum MapLinkMetadata {
    enum Provider {
        case apple
        case google

        var displayName: String {
            switch self {
            case .apple: "Apple Maps"
            case .google: "Google Maps"
            }
        }
    }

    static func provider(for rawURL: String) -> Provider? {
        guard let components = URLComponents(string: rawURL),
              let host = components.host?.lowercased() else { return nil }
        if host == "maps.apple.com" || host == "maps.apple" { return .apple }
        if host == "maps.app.goo.gl" || host == "maps.google.com" ||
            (host == "goo.gl" && components.path.hasPrefix("/maps")) {
            return .google
        }
        if (host == "google.com" || host == "www.google.com") &&
            (components.path.hasPrefix("/maps/") || components.path == "/maps" ||
             components.path.hasPrefix("/local/userlists/")) {
            return .google
        }
        return nil
    }

    static func isCollectionLink(_ rawURL: String) -> Bool {
        guard let components = URLComponents(string: rawURL),
              let provider = provider(for: rawURL) else { return false }
        switch provider {
        case .apple:
            return components.path == "/guides" ||
                components.path.hasPrefix("/guides/") ||
                components.path.hasPrefix("/ug/")
        case .google:
            return components.path.hasPrefix("/maps/placelists/") ||
                components.path.hasPrefix("/local/userlists/")
        }
    }

    static func placeName(from rawURL: String) -> String? {
        guard let components = URLComponents(string: rawURL),
              let provider = provider(for: rawURL) else { return nil }

        switch provider {
        case .apple:
            return components.queryItems?
                .first(where: { ["q", "name"].contains($0.name.lowercased()) })?
                .value?
                .replacingOccurrences(of: "+", with: " ")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        case .google:
            let path = components.path.split(separator: "/")
            guard let placeIndex = path.firstIndex(of: "place"),
                  path.indices.contains(placeIndex + 1) else { return nil }
            return String(path[placeIndex + 1])
                .replacingOccurrences(of: "+", with: " ")
                .removingPercentEncoding?
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
    }
}
