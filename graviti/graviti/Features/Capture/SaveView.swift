import SwiftUI

struct SaveView: View {
    @ObservedObject var library: ArtifactLibrary
    let onViewLibrary: () -> Void

    @State private var kind: ArtifactKind = .url
    @State private var urlText = ""
    @State private var noteText = ""
    @State private var optionalNote = ""
    @State private var isSaving = false
    @State private var didSave = false
    @State private var saveError: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    Text("Save what pulls you.")
                        .font(.custom("Sora-SemiBold", size: 26, relativeTo: .title))
                        .foregroundStyle(.white)

                    Picker("Save type", selection: $kind) {
                        Text("Link").tag(ArtifactKind.url)
                        Text("Note").tag(ArtifactKind.manual)
                    }
                    .pickerStyle(.segmented)

                    if kind == .url {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Link")
                                .font(.headline)
                            TextField("Paste a link", text: $urlText)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.URL)
                                .textContentType(.URL)
                                .padding(14)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }

                        VStack(alignment: .leading, spacing: 10) {
                            Text("A note, if you like")
                                .font(.headline)
                            TextField("What caught your eye?", text: $optionalNote, axis: .vertical)
                                .lineLimit(2...4)
                                .padding(14)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                    } else {
                        VStack(alignment: .leading, spacing: 10) {
                            Text("Your note")
                                .font(.headline)
                            TextEditor(text: $noteText)
                                .scrollContentBackground(.hidden)
                                .frame(minHeight: 140)
                                .padding(10)
                                .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 12))
                        }
                    }

                    Button {
                        Task { await save() }
                    } label: {
                        HStack {
                            Spacer()
                            if isSaving {
                                ProgressView().tint(.white)
                            } else {
                                Text("Save to Graviti")
                                    .font(.headline)
                            }
                            Spacer()
                        }
                        .frame(minHeight: 50)
                        .background(GravitiColors.iris, in: RoundedRectangle(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                    .disabled(!canSave || isSaving)
                    .opacity(canSave ? 1 : 0.5)

                    if didSave {
                        HStack {
                            Label("Saved to Graviti", systemImage: "checkmark.circle.fill")
                                .foregroundStyle(GravitiColors.signalMint)
                            Spacer()
                            Button("View in Library", action: onViewLibrary)
                                .fontWeight(.semibold)
                        }
                        .font(.subheadline)
                        .accessibilityElement(children: .contain)
                    }

                    if let saveError {
                        Text(saveError)
                            .font(.subheadline)
                            .foregroundStyle(GravitiColors.opportunityCoral)
                    }
                }
                .padding(20)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(GravitiColors.appBackground)
            .foregroundStyle(.white)
            .navigationTitle("Save")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onChange(of: kind) { _, _ in didSave = false }
        .onChange(of: urlText) { _, newValue in
            if !newValue.isEmpty { didSave = false }
        }
        .onChange(of: noteText) { _, newValue in
            if !newValue.isEmpty { didSave = false }
        }
    }

    private var canSave: Bool {
        switch kind {
        case .url:
            guard let components = URLComponents(string: urlText.trimmingCharacters(in: .whitespacesAndNewlines)),
                  let scheme = components.scheme?.lowercased(),
                  ["http", "https"].contains(scheme),
                  let host = components.host, !host.isEmpty else {
                return false
            }
            return true
        case .manual:
            return !noteText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }

    private func save() async {
        guard canSave, !isSaving else { return }
        isSaving = true
        didSave = false
        saveError = nil

        let artifact: Artifact
        switch kind {
        case .url:
            artifact = Artifact(
                kind: .url,
                sourceURL: urlText.trimmingCharacters(in: .whitespacesAndNewlines),
                userNote: optionalNote.trimmingCharacters(in: .whitespacesAndNewlines).nilIfEmpty
            )
        case .manual:
            artifact = Artifact(
                kind: .manual,
                originalText: noteText.trimmingCharacters(in: .whitespacesAndNewlines)
            )
        }

        do {
            try await library.save(artifact)
            urlText = ""
            noteText = ""
            optionalNote = ""
            didSave = true
        } catch {
            saveError = error.localizedDescription
        }
        isSaving = false
    }
}

private extension String {
    var nilIfEmpty: String? { isEmpty ? nil : self }
}
