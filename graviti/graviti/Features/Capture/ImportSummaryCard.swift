import SwiftUI

struct ImportSummaryCard: View {
    let summary: SaveImportSummary

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label(summary.title, systemImage: "checkmark.circle.fill")
                .font(.headline)
                .foregroundStyle(GravitiColors.signalMint)

            ViewThatFits(in: .horizontal) {
                HStack(spacing: 16) { metrics }
                VStack(alignment: .leading, spacing: 8) { metrics }
            }
            .font(.subheadline)

            if summary.processingContinues {
                Text("Place details will continue organizing in the background.")
                    .font(.caption)
                    .foregroundStyle(.white.opacity(0.65))
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(GravitiColors.deepInk, in: RoundedRectangle(cornerRadius: 16))
        .accessibilityElement(children: .combine)
    }

    @ViewBuilder
    private var metrics: some View {
        metric(summary.imported, label: "imported")
        if summary.countries > 0 { metric(summary.countries, label: "countries") }
        if summary.cities > 0 { metric(summary.cities, label: "cities") }
        if summary.duplicates > 0 { metric(summary.duplicates, label: "duplicates avoided") }
        if summary.skipped > 0 { metric(summary.skipped, label: "couldn’t import") }
    }

    private func metric(_ value: Int, label: LocalizedStringKey) -> some View {
        HStack(spacing: 5) {
            Text(value, format: .number).fontWeight(.semibold)
            Text(label)
        }
    }
}

struct SaveImportSummary {
    let title: String
    let imported: Int
    var duplicates = 0
    var skipped = 0
    var countries = 0
    var cities = 0
    var processingContinues = false
}
