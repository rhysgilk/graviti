import Foundation

enum InterestDisplayName {
    static func localized(_ value: String, locale: Locale? = nil) -> String {
        let localized: (String) -> String = { key in
            guard
                let languageCode = locale?.language.languageCode?.identifier,
                let resourcePath = Bundle.main.path(forResource: languageCode, ofType: "lproj"),
                let resourceBundle = Bundle(path: resourcePath)
            else {
                return String(localized: String.LocalizationValue(key))
            }
            return resourceBundle.localizedString(forKey: key, value: key, table: nil)
        }

        return switch value {
        case "Matcha": localized("Matcha")
        case "Tea": localized("Tea")
        case "Coffee": localized("Coffee")
        case "Desserts": localized("Desserts")
        case "Ramen": localized("Ramen")
        case "Seafood": localized("Seafood")
        case "Scenic views": localized("Scenic views")
        case "National parks": localized("National parks")
        case "Mountains": localized("Mountains")
        case "Coast & water": localized("Coast & water")
        case "Forests": localized("Forests")
        case "Wildlife": localized("Wildlife")
        case "Hiking": localized("Hiking")
        case "Beaches": localized("Beaches")
        case "Architecture": localized("Architecture")
        case "History": localized("History")
        case "Museums": localized("Museums")
        case "Gardens": localized("Gardens")
        case "Shopping": localized("Shopping")
        case "Nature": localized("Nature")
        default: value
        }
    }

    static func joined(
        _ values: some Sequence<String>,
        separator: String = " · ",
        locale: Locale? = nil
    ) -> String {
        var localizedValues: [String] = []
        for value in values {
            localizedValues.append(localized(value, locale: locale))
        }
        return localizedValues.joined(separator: separator)
    }
}
