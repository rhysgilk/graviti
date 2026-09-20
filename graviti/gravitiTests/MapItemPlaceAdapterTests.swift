import MapKit
import XCTest
@testable import graviti

@MainActor
final class MapItemPlaceAdapterTests: XCTestCase {
    func testMapItemBecomesStableSavedPlace() throws {
        let item = makeMapItem(latitude: 35.0116, longitude: 135.7681)
        item.name = "  Nishiki Market  "

        let place = try XCTUnwrap(MapItemPlaceAdapter.savedPlace(from: item, fallbackID: "nishiki"))

        XCTAssertEqual(place.id, "nishiki")
        XCTAssertEqual(place.name, "Nishiki Market")
        XCTAssertEqual(place.latitude, 35.0116, accuracy: 0.000_001)
        XCTAssertEqual(place.longitude, 135.7681, accuracy: 0.000_001)
    }

    func testMapItemWithoutNameIsRejected() {
        let item = makeMapItem(latitude: 0, longitude: 0)
        item.name = "   "

        XCTAssertNil(MapItemPlaceAdapter.savedPlace(from: item))
    }

    private func makeMapItem(latitude: CLLocationDegrees, longitude: CLLocationDegrees) -> MKMapItem {
        let location = CLLocation(latitude: latitude, longitude: longitude)
        if #available(iOS 26.0, *) {
            return MKMapItem(location: location, address: nil)
        } else {
            return legacyMapItem(coordinate: location.coordinate)
        }
    }

    @available(iOS, obsoleted: 26.0)
    private func legacyMapItem(coordinate: CLLocationCoordinate2D) -> MKMapItem {
        MKMapItem(placemark: MKPlacemark(coordinate: coordinate))
    }
}
