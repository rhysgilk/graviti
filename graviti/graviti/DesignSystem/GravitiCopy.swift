import Foundation

enum GravitiCopy {
    static func savedItems(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 saved item")
            : String(localized: "\(count) saved items")
    }

    static func saves(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 save")
            : String(localized: "\(count) saves")
    }

    static func preferences(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 preference")
            : String(localized: "\(count) preferences")
    }

    static func savesAcrossAreas(_ saveCount: Int, areaCount: Int) -> String {
        saveCount == 1
            ? String(localized: "1 save across \(areaCount) areas")
            : String(localized: "\(saveCount) saves across \(areaCount) areas")
    }

    static func savesAtPlaces(_ saveCount: Int, placeCount: Int) -> String {
        saveCount == 1
            ? String(localized: "1 save at \(placeCount) places")
            : String(localized: "\(saveCount) saves at \(placeCount) places")
    }

    static func sharedImportNotice(_ count: Int) -> String {
        count == 1
            ? String(localized: "Added 1 shared save to your Library")
            : String(localized: "Added \(count) shared saves to your Library")
    }

    static func removeSelectedPlacesQuestion(_ count: Int) -> String {
        count == 1
            ? String(localized: "Remove the selected place?")
            : String(localized: "Remove \(count) selected places?")
    }

    static func removeSelectedPlacesLabel(_ count: Int) -> String {
        count == 1
            ? String(localized: "Remove selected place")
            : String(localized: "Remove \(count) selected places")
    }

    static func deleteSelectedSavesQuestion(_ count: Int) -> String {
        count == 1
            ? String(localized: "Delete the selected save?")
            : String(localized: "Delete \(count) selected saves?")
    }

    static func deleteSelectedSavesLabel(_ count: Int) -> String {
        count == 1
            ? String(localized: "Delete selected save")
            : String(localized: "Delete \(count) selected saves")
    }

    static func repeatedPlaces(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 place combines multiple saves")
            : String(localized: "\(count) places combine multiple saves")
    }

    static func restoreSummary(imported: Int, duplicates: Int) -> String {
        let restored = imported == 1
            ? String(localized: "1 save restored")
            : String(localized: "\(imported) saves restored")
        guard duplicates > 0 else { return restored + "." }
        let existing = duplicates == 1
            ? String(localized: "1 duplicate already present")
            : String(localized: "\(duplicates) duplicates already present")
        return String(localized: "\(restored) · \(existing).")
    }

    static func imported(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 imported")
            : String(localized: "\(count) imported")
    }

    static func placeDetailsRefreshed(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 place detail refreshed")
            : String(localized: "\(count) place details refreshed")
    }

    static func duplicatesAvoided(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 duplicate avoided")
            : String(localized: "\(count) duplicates avoided")
    }

    static func couldNotImport(_ count: Int) -> String {
        count == 1
            ? String(localized: "1 couldn't import")
            : String(localized: "\(count) couldn't import")
    }
}
