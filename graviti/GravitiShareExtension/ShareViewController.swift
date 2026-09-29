import UIKit
import UniformTypeIdentifiers

final class ShareViewController: UIViewController {
    private let sourceTitleLabel = UILabel()
    private let sourceDetailLabel = UILabel()
    private let noteField = UITextView()
    private let guideField = UITextField()
    private let tagField = UITextField()
    private let prioritySwitch = UISwitch()
    private let skipIdentificationSwitch = UISwitch()
    private let saveButton = UIButton(type: .system)
    private let statusLabel = UILabel()

    private var sharedURL: String?
    private var sharedText: String?
    private var sharedImage: (data: Data, fileExtension: String)?
    private var detectedTitle: String?
    private var isLoading = true

    override func viewDidLoad() {
        super.viewDidLoad()
        configureUI()
        Task { await loadSharedContent() }
    }

    private func configureUI() {
        view.backgroundColor = UIColor(red: 0.035, green: 0.039, blue: 0.075, alpha: 1)

        let title = UILabel()
        title.text = String(localized: "Save to Graviti")
        title.font = .preferredFont(forTextStyle: .title2).bold()
        title.textColor = .white

        let cancel = UIButton(type: .system)
        cancel.setTitle(String(localized: "Cancel"), for: .normal)
        cancel.addTarget(self, action: #selector(cancelTapped), for: .touchUpInside)

        let header = UIStackView(arrangedSubviews: [title, UIView(), cancel])
        header.axis = .horizontal
        header.alignment = .center

        sourceTitleLabel.font = .preferredFont(forTextStyle: .headline)
        sourceTitleLabel.textColor = .white
        sourceTitleLabel.numberOfLines = 2
        sourceTitleLabel.text = String(localized: "Reading shared item…")
        sourceDetailLabel.font = .preferredFont(forTextStyle: .subheadline)
        sourceDetailLabel.textColor = .secondaryLabel
        sourceDetailLabel.numberOfLines = 2

        let sourceStack = UIStackView(arrangedSubviews: [sourceTitleLabel, sourceDetailLabel])
        sourceStack.axis = .vertical
        sourceStack.spacing = 5
        sourceStack.isLayoutMarginsRelativeArrangement = true
        sourceStack.layoutMargins = UIEdgeInsets(top: 16, left: 16, bottom: 16, right: 16)
        sourceStack.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        sourceStack.layer.cornerRadius = 16

        noteField.font = .preferredFont(forTextStyle: .body)
        noteField.textColor = .white
        noteField.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        noteField.layer.cornerRadius = 14
        noteField.textContainerInset = UIEdgeInsets(top: 12, left: 10, bottom: 12, right: 10)
        noteField.heightAnchor.constraint(equalToConstant: 92).isActive = true
        noteField.accessibilityLabel = String(localized: "Optional note")
        noteField.inputAccessoryView = keyboardToolbar()

        configure(field: guideField, placeholder: String(localized: "Guide name (optional)"))
        configure(field: tagField, placeholder: String(localized: "Tags, separated by commas"))

        let priorityRow = optionRow(
            title: String(localized: "High priority"),
            detail: String(localized: "Mark this as especially important"),
            control: prioritySwitch
        )
        let skipRow = optionRow(
            title: String(localized: "Save without finding a place"),
            detail: String(localized: "Keep the source and note only"),
            control: skipIdentificationSwitch
        )

        saveButton.setTitle(String(localized: "Save"), for: .normal)
        saveButton.titleLabel?.font = .preferredFont(forTextStyle: .headline)
        saveButton.setTitleColor(.white, for: .normal)
        saveButton.backgroundColor = UIColor(red: 0.40, green: 0.32, blue: 0.95, alpha: 1)
        saveButton.layer.cornerRadius = 15
        saveButton.heightAnchor.constraint(equalToConstant: 54).isActive = true
        saveButton.isEnabled = false
        saveButton.addTarget(self, action: #selector(saveTapped), for: .touchUpInside)

        statusLabel.font = .preferredFont(forTextStyle: .subheadline)
        statusLabel.textColor = UIColor(red: 0.35, green: 0.93, blue: 0.72, alpha: 1)
        statusLabel.textAlignment = .center
        statusLabel.numberOfLines = 2

        let stack = UIStackView(arrangedSubviews: [
            header,
            sourceStack,
            sectionLabel(String(localized: "Why did you save this?")),
            noteField,
            guideField,
            tagField,
            priorityRow,
            skipRow,
            saveButton,
            statusLabel
        ])
        stack.axis = .vertical
        stack.spacing = 14

        let scrollView = UIScrollView()
        scrollView.keyboardDismissMode = .onDrag
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        stack.translatesAutoresizingMaskIntoConstraints = false
        view.addSubview(scrollView)
        scrollView.addSubview(stack)

        NSLayoutConstraint.activate([
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
            stack.leadingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.leadingAnchor, constant: 20),
            stack.trailingAnchor.constraint(equalTo: scrollView.contentLayoutGuide.trailingAnchor, constant: -20),
            stack.topAnchor.constraint(equalTo: scrollView.contentLayoutGuide.topAnchor, constant: 18),
            stack.bottomAnchor.constraint(equalTo: scrollView.contentLayoutGuide.bottomAnchor, constant: -24),
            stack.widthAnchor.constraint(equalTo: scrollView.frameLayoutGuide.widthAnchor, constant: -40)
        ])
    }

    private func configure(field: UITextField, placeholder: String) {
        field.placeholder = placeholder
        field.font = .preferredFont(forTextStyle: .body)
        field.textColor = .white
        field.backgroundColor = UIColor.white.withAlphaComponent(0.07)
        field.layer.cornerRadius = 13
        field.setLeftPadding(12)
        field.heightAnchor.constraint(equalToConstant: 50).isActive = true
        field.autocorrectionType = .yes
        field.inputAccessoryView = keyboardToolbar()
    }

    private func keyboardToolbar() -> UIToolbar {
        let toolbar = UIToolbar()
        toolbar.sizeToFit()
        toolbar.items = [
            UIBarButtonItem(systemItem: .flexibleSpace),
            UIBarButtonItem(
                title: String(localized: "Done"),
                style: .done,
                target: self,
                action: #selector(dismissKeyboard)
            )
        ]
        return toolbar
    }

    @objc private func dismissKeyboard() {
        view.endEditing(true)
    }

    private func sectionLabel(_ text: String) -> UILabel {
        let label = UILabel()
        label.text = text
        label.font = .preferredFont(forTextStyle: .subheadline).bold()
        label.textColor = .white
        return label
    }

    private func optionRow(title: String, detail: String, control: UISwitch) -> UIView {
        let titleLabel = UILabel()
        titleLabel.text = title
        titleLabel.font = .preferredFont(forTextStyle: .body)
        titleLabel.textColor = .white
        let detailLabel = UILabel()
        detailLabel.text = detail
        detailLabel.font = .preferredFont(forTextStyle: .caption1)
        detailLabel.textColor = .secondaryLabel
        detailLabel.numberOfLines = 2
        let labels = UIStackView(arrangedSubviews: [titleLabel, detailLabel])
        labels.axis = .vertical
        labels.spacing = 2
        let row = UIStackView(arrangedSubviews: [labels, UIView(), control])
        row.axis = .horizontal
        row.alignment = .center
        row.isLayoutMarginsRelativeArrangement = true
        row.layoutMargins = UIEdgeInsets(top: 10, left: 12, bottom: 10, right: 12)
        row.backgroundColor = UIColor.white.withAlphaComponent(0.05)
        row.layer.cornerRadius = 13
        return row
    }

    private func loadSharedContent() async {
        do {
            sharedURL = try await firstItem(of: .url)
            sharedText = sharedURL == nil ? try await firstItem(of: .plainText) : nil
            if sharedURL == nil, validWebURL(sharedText) == nil {
                sharedImage = try await firstImage()
            }
            if let item = (extensionContext?.inputItems as? [NSExtensionItem])?.first {
                detectedTitle = item.attributedTitle?.string.nilIfEmpty
                    ?? item.attributedContentText?.string.nilIfEmpty
            }
            if detectedTitle == nil {
                detectedTitle = providers.compactMap(\.suggestedName).first?.nilIfEmpty
            }
            updateSourcePreview()
            isLoading = false
            saveButton.isEnabled = hasSavableContent
        } catch {
            showError(error)
        }
    }

    private func updateSourcePreview() {
        if let rawURL = sharedURL ?? validWebURL(sharedText), let url = URL(string: rawURL) {
            sourceTitleLabel.text = detectedTitle ?? url.host ?? String(localized: "Shared link")
            sourceDetailLabel.text = url.host ?? rawURL
        } else if sharedImage != nil {
            sourceTitleLabel.text = detectedTitle ?? String(localized: "Shared photo")
            sourceDetailLabel.text = String(localized: "Photo · Graviti can read visible text after saving")
        } else {
            sourceTitleLabel.text = detectedTitle ?? sharedText ?? String(localized: "Shared note")
            sourceDetailLabel.text = String(localized: "Text save")
        }
    }

    @objc private func saveTapped() {
        guard !isLoading else { return }
        saveButton.isEnabled = false
        view.endEditing(true)
        Task {
            do {
                let envelope = try makeEnvelope()
                do {
                    try SharedArtifactInbox.enqueue(envelope)
                } catch {
                    if let mediaKey = envelope.mediaKey { try? SharedMediaStore.remove(mediaKey) }
                    throw error
                }
                statusLabel.text = skipIdentificationSwitch.isOn
                    ? String(localized: "Saved to Graviti")
                    : String(localized: "Saved to Graviti\nFinding the place and adding details…")
                try? await Task.sleep(for: .milliseconds(650))
                extensionContext?.completeRequest(returningItems: nil)
            } catch {
                saveButton.isEnabled = true
                showError(error)
            }
        }
    }

    @objc private func cancelTapped() {
        extensionContext?.cancelRequest(withError: ShareError.cancelled)
    }

    private func makeEnvelope() throws -> SharedArtifactEnvelope {
        let sourceURL = validWebURL(sharedURL ?? sharedText)
        let id = UUID()
        let mediaKey: String?
        if let image = sharedImage {
            mediaKey = try SharedMediaStore.store(image.data, id: id, fileExtension: image.fileExtension)
        } else {
            mediaKey = nil
        }
        let originalText = sourceURL == nil && mediaKey == nil
            ? (sharedText ?? detectedTitle)?.nilIfEmpty
            : detectedTitle
        let note = noteField.text.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        let guide = guideField.text?.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
        var seen = Set<String>()
        let tags = (tagField.text ?? "").split(separator: ",")
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty && seen.insert($0.lowercased()).inserted }
        guard sourceURL != nil || originalText != nil || mediaKey != nil else { throw ShareError.empty }
        return SharedArtifactEnvelope(
            id: id,
            sourceURL: sourceURL,
            originalText: originalText,
            userNote: note,
            mediaKey: mediaKey,
            sourceCollectionTitle: guide,
            isHighPriority: prioritySwitch.isOn,
            tags: tags,
            skipPlaceIdentification: skipIdentificationSwitch.isOn,
            capturedAt: .now
        )
    }

    private var providers: [NSItemProvider] {
        (extensionContext?.inputItems as? [NSExtensionItem] ?? []).flatMap { $0.attachments ?? [] }
    }

    private var hasSavableContent: Bool {
        validWebURL(sharedURL ?? sharedText) != nil || sharedText?.nilIfEmpty != nil || sharedImage != nil
    }

    private func firstImage() async throws -> (data: Data, fileExtension: String)? {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(UTType.image.identifier) }) else { return nil }
        let identifier = provider.registeredTypeIdentifiers.first { UTType($0)?.conforms(to: .image) == true }
            ?? UTType.image.identifier
        let fileExtension = UTType(identifier)?.preferredFilenameExtension ?? "jpg"
        let data: Data = try await withCheckedThrowingContinuation { continuation in
            provider.loadDataRepresentation(forTypeIdentifier: identifier) { data, error in
                if let error { continuation.resume(throwing: error) }
                else if let data { continuation.resume(returning: data) }
                else { continuation.resume(throwing: ShareError.unsupported) }
            }
        }
        guard UIImage(data: data) != nil else { throw ShareError.unsupported }
        return (data, fileExtension)
    }

    private func firstItem(of type: UTType) async throws -> String? {
        guard let provider = providers.first(where: { $0.hasItemConformingToTypeIdentifier(type.identifier) }) else { return nil }
        return try await withCheckedThrowingContinuation { continuation in
            provider.loadItem(forTypeIdentifier: type.identifier, options: nil) { value, error in
                if let error { continuation.resume(throwing: error) }
                else if let url = value as? URL { continuation.resume(returning: url.absoluteString) }
                else if let text = value as? String { continuation.resume(returning: text) }
                else { continuation.resume(throwing: ShareError.unsupported) }
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

    private func showError(_ error: Error) {
        statusLabel.textColor = .systemOrange
        statusLabel.text = error.localizedDescription
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}

private extension UIFont {
    func bold() -> UIFont {
        UIFont(descriptor: fontDescriptor.withSymbolicTraits(.traitBold) ?? fontDescriptor, size: pointSize)
    }
}

private extension UITextField {
    func setLeftPadding(_ amount: CGFloat) {
        let padding = UIView(frame: CGRect(x: 0, y: 0, width: amount, height: 1))
        leftView = padding
        leftViewMode = .always
    }
}

private enum ShareError: LocalizedError {
    case empty
    case unsupported
    case cancelled

    var errorDescription: String? {
        switch self {
        case .empty: String(localized: "There’s no link, text, or photo to save.")
        case .unsupported: String(localized: "This app shared content Graviti can’t read yet.")
        case .cancelled: String(localized: "Save cancelled.")
        }
    }
}
