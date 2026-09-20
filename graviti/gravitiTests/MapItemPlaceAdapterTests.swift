import MapKit
import XCTest
@testable import graviti

@MainActor
final class MapItemPlaceAdapterTests: XCTestCase {
    @available(iOS 26.0, *)
    func testMapItemBecomesStableSavedPlace() throws {
        let item = MKMapItem(
            location: CLLocation(latitude: 35.0116, longitude: 135.7681),
            address: nil
        )
        item.name = "  Nishiki Market  "

        let place = try XCTUnwrap(MapItemPlaceAdapter.savedPlace(from: item, fallbackID: "nishiki"))

        XCTAssertEqual(place.id, "nishiki")
        XCTAssertEqual(place.name, "Nishiki Market")
        XCTAssertEqual(place.latitude, 35.0116, accuracy: 0.000_001)
        XCTAssertEqual(place.longitude, 135.7681, accuracy: 0.000_001)
    }

    @available(iOS 26.0, *)
    func testMapItemWithoutNameIsRejected() {
        let item = MKMapItem(
            location: CLLocation(latitude: 0, longitude: 0),
            address: nil
        )
        item.name = "   "

        XCTAssertNil(MapItemPlaceAdapter.savedPlace(from: item))
    }
}
