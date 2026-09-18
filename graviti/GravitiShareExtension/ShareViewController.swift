import Social
import UniformTypeIdentifiers

final class ShareViewController: SLComposeServiceViewController {
    private var sharedTitle: String?

    override func viewDidLoad() {
        super.viewDidLoad()
        if providers.contains(where: { $0.hasItemConformingToTypeIdentifier(UTType.url.identifier) }) {
            sharedTitle = (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        }
    }

    override func isContentValid() -> Bool {
        let hasAttachment = providers.contains {
            $0.hasItemConformingToTypeIdentifier(UTType.url.identifier)
                || $0.hasItemConformingToTypeIdentifier(UTType.plainText.identifier)
        }
        return hasAttachment || !(contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }

    override func didSelectPost() {
        Task {
            do {
                let envelope = try await makeEnvelope()
                try SharedArtifactInbox.enqueue(envelope)
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                let alert = UIAlertController(
                    title: "Couldn't save to Graviti",
                    message: error.localizedDescription,
                    preferredStyle: .alert
                )
                alert.addAction(UIAlertAction(title: "OK", style: .default))
                present(alert, animated: true)
            }
        }
    }

    private var providers: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem] ?? [])
            .flatMap { $0.attachments ?? [] }
    }

    private func makeEnvelope() async throws -> SharedArtifactEnvelope {
        let sharedURL = try await firstItem(of: .url)
        let sharedText = sharedURL == nil ? try await firstItem(of: .plainText) : nil
        let composedText = (contentText ?? "").trimmingCharacters(in: .whitespacesAndNewlines)

        let sourceURL = validWebURL(sharedURL ?? sharedText)
        let originalText = sourceURL == nil ? (sharedText ?? composedText).nilIfEmpty : sharedTitle
        let userNote = sourceURL != nil && composedText != sharedText &&
            composedText != sharedURL && composedText != sharedTitle
            ? composedText.nilIfEmpty : nil

        guard sourceURL != nil || originalText != nil else { throw ShareError.empty }
        return SharedArtifactEnvelope(
            id: UUID(),
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: userNote,
            capturedAt: .now
        )
    }

    private func firstItem(of type: UTType) async throws -> String? {
        guard let provider = providers.first(where: {
            $0.hasItemConformingToTypeIdentifier(type.identifier)
        }) else { return nil }

        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { value, error in
                if let error {
                    continuation.resume(throwing: error)
                } else if let url = value as? URL {
                    continuation.resume(returning: url.absoluteString)
                } else if let text = value as? String {
                    continuation.resume(returning: text)
                } else {
                    continuation.resume(throwing: ShareError.unsupported)
                }
            }
        }
    }

    private func validWebURL(_ raw: String?) -> String? {
        guard let raw,
              let components = URLComponents(string: raw),
              let scheme = components.scheme?.lowercased(),
              ["http", "https"].contains(scheme),
              components.host != nil else { return nil }
        return raw
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private enum ShareError: LocalizedError {
    case empty
    case unsupported

    var errorDescription: String? {
        switch self {
        case .empty: "There's no link or text to save."
        case .unsupported: "This app shared content Graviti can't read yet."
        }
    }
}
