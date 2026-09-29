import Foundation
import MapKit

enum MapItemPlaceAdapter {
    static func savedPlace(from item: MKMapItem, fallbackID: String? = nil) -> SavedPlace? {
        guard let name = item.name?.trimmingCharacters(in: .whitespacesAndNewlines), !name.isEmpty else {
            return nil
        }

        let coordinate: CLLocationCoordinate2D
        let locality: String?
        let region: String?
        let country: String?
        if #available(iOS 26.0, *) {
            coordinate = item.location.coordinate
            let address = item.addressRepresentations
            locality = cleaned(address?.cityName)
            country = cleaned(address?.regionName)
            region = regionName(
                cityName: locality,
                cityWithContext: address?.cityWithContext,
                country: country
            )
        } else {
            coordinate = item.placemark.coordinate
            locality = item.placemark.locality
            region = item.placemark.administrativeArea
            country = item.placemark.country
        }

        return SavedPlace(
            id: item.identifier?.rawValue ?? fallbackID ?? String(
                format: "%.5f,%.5f:%@",
                coordinate.latitude,
                coordinate.longitude,
                name
            ),
            name: name,
            latitude: coordinate.latitude,
            longitude: coordinate.longitude,
            locality: locality,
            region: region,
            country: country
        )
    }

    static func regionName(cityName: String?, cityWithContext: String?, country: String?) -> String? {
        guard let context = cleaned(cityWithContext) else { return nil }
        var components = context.split(separator: ",", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
        if let cityName,
           components.first.map({ normalized($0) == normalized(cityName) }) == true {
            components.removeFirst()
        }
        if let country,
           components.last.map({ normalized($0) == normalized(country) }) == true {
            components.removeLast()
        }
        guard let rawRegion = components.last, !rawRegion.isEmpty else { return nil }
        return subdivisionNames[normalized(rawRegion)] ?? rawRegion
    }

    private static func cleaned(_ value: String?) -> String? {
        guard let value = value?.trimmingCharacters(in: .whitespacesAndNewlines), !value.isEmpty else { return nil }
        return value
    }

    private static func normalized(_ value: String) -> String {
        value.folding(options: [.caseInsensitive, .diacriticInsensitive], locale: Locale(identifier: "en_US_POSIX"))
    }

    private static let subdivisionNames: [String: String] = {
        let values = [
            "AL:Alabama", "AK:Alaska", "AZ:Arizona", "AR:Arkansas", "CA:California", "CO:Colorado",
            "CT:Connecticut", "DE:Delaware", "FL:Florida", "GA:Georgia", "HI:Hawaii", "ID:Idaho",
            "IL:Illinois", "IN:Indiana", "IA:Iowa", "KS:Kansas", "KY:Kentucky", "LA:Louisiana",
            "ME:Maine", "MD:Maryland", "MA:Massachusetts", "MI:Michigan", "MN:Minnesota",
            "MS:Mississippi", "MO:Missouri", "MT:Montana", "NE:Nebraska", "NV:Nevada",
            "NH:New Hampshire", "NJ:New Jersey", "NM:New Mexico", "NY:New York",
            "NC:North Carolina", "ND:North Dakota", "OH:Ohio", "OK:Oklahoma", "OR:Oregon",
            "PA:Pennsylvania", "RI:Rhode Island", "SC:South Carolina", "SD:South Dakota",
            "TN:Tennessee", "TX:Texas", "UT:Utah", "VT:Vermont", "VA:Virginia",
            "WA:Washington", "WV:West Virginia", "WI:Wisconsin", "WY:Wyoming", "DC:District of Columbia",
            "AB:Alberta", "BC:British Columbia", "MB:Manitoba", "NB:New Brunswick",
            "NL:Newfoundland and Labrador", "NS:Nova Scotia", "NT:Northwest Territories",
            "NU:Nunavut", "ON:Ontario", "PE:Prince Edward Island", "QC:Quebec",
            "SK:Saskatchewan", "YT:Yukon"
        ]
        return Dictionary(uniqueKeysWithValues: values.compactMap { entry in
            let pieces = entry.split(separator: ":", maxSplits: 1).map(String.init)
            guard pieces.count == 2 else { return nil }
            return (normalized(pieces[0]), pieces[1])
        })
    }()
}
