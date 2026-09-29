import SwiftUI

struct CompletenessReviewView: View {
    @Environment(\.dismiss) private var dismiss
    @ObservedObject var library: ArtifactLibrary

    private var incomplete: [Artifact] {
        library.artifacts.filter { !$0.completeness.isComplete }.sorted {
            $0.completeness.score == $1.completeness.score
                ? $0.capturedAt > $1.capturedAt
                : $0.completeness.score < $1.completeness.score
        }
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Graviti keeps filling details automatically. This queue highlights the few saves where a personal note, correction, or retry can make future recommendations more useful.")
                        .font(GravitiTypography.subheadline)
                        .foregroundStyle(.secondary)
                }
                ForEach(incomplete) { artifact in
                    NavigationLink {
                        SavedArtifactDetailView(artifact: artifact, library: library)
                    } label: {
                        VStack(alignment: .leading, spacing: 7) {
                            Text(LibrarySearchEngine.title(for: artifact))
                                .font(GravitiTypography.headline)
                                .lineLimit(2)
                            ScrollView(.horizontal, showsIndicators: false) {
                                HStack(spacing: 6) {
                                    ForEach(artifact.completeness.gaps, id: \.self) { gap in
                                        Label(gap.title, systemImage: gap.symbol)
                                            .font(GravitiTypography.caption)
                                            .padding(.horizontal, 9)
                                            .padding(.vertical, 5)
                                            .background(GravitiColors.opportunityCoral.opacity(0.16), in: Capsule())
                                    }
                                }
                            }
                        }
                        .padding(.vertical, 5)
                    }
                }
            }
            .scrollContentBackground(.hidden)
            .background(GravitiColors.appBackground)
            .navigationTitle("Complete saves")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Done") { dismiss() } } }
        }
    }
}
