import XCTest
@testable import graviti

final class ImportParserTests: XCTestCase {
    func testGoogleCSVHandlesQuotedCommasNewlinesAndEscapedQuotes() throws {
        let csv = """
        metadata row
        Title,item_content_url,Note
        "Pike Place, Market",https://maps.google.com/?cid=1,"Seafood, history, and a \"\"must see\"\" market"
        Tea House,https://maps.google.com/?cid=2,"Quiet tea room
        with a garden"
        Missing URL,,Skipped
        """

        let result = try GoogleSavedCSVParser.parse(csv)

        XCTAssertEqual(result.rows.count, 2)
        XCTAssertEqual(result.skippedRows, 1)
        XCTAssertEqual(result.rows[0].title, "Pike Place, Market")
        XCTAssertEqual(result.rows[0].note, "Seafood, history, and a \"must see\" market")
        XCTAssertTrue(result.rows[1].note?.contains("\n") == true)
    }

    func testGoogleCSVRejectsUnclosedQuote() {
        XCTAssertThrowsError(try GoogleSavedCSVParser.parse("Title,URL\n\"Broken,https://example.com"))
    }

    func testAppleGuideDecodesTitleAndDeduplicatesPlaceIdentifiers() throws {
        let payload = guidePayload(title: "Weekend favorites", placeIDs: [42, 42, 9_999])
        var components = URLComponents(string: "https://maps.apple.com/guides")!
        components.queryItems = [URLQueryItem(name: "user", value: payload.base64EncodedString())]

        let guide = try AppleMapsGuideParser.parse(try XCTUnwrap(components.url?.absoluteString))

        XCTAssertEqual(guide.title, "Weekend favorites")
        XCTAssertEqual(guide.placeIdentifiers, ["I000000000000002A", "I000000000000270F"])
    }

    func testAppleGuideRejectsWrongNamespace() {
        let payload = guidePayload(title: "Wrong namespace", placeIDs: [42], namespace: 1)
        var components = URLComponents(string: "https://maps.apple.com/guides")!
        components.queryItems = [URLQueryItem(name: "user", value: payload.base64EncodedString())]
        XCTAssertThrowsError(try AppleMapsGuideParser.parse(components.url!.absoluteString))
    }

    private func guidePayload(title: String, placeIDs: [UInt64], namespace: UInt64 = 9_902) -> Data {
        var bytes = field(number: 1, bytes: Array(title.utf8))
        for id in placeIDs {
            let place = field(number: 1, integer: namespace) + field(number: 2, integer: id)
            bytes += field(number: 2, bytes: place)
        }
        return Data(bytes)
    }

    private func field(number: UInt64, integer: UInt64) -> [UInt8] {
        var result = varint(number << 3)
        result += varint(integer)
        return result
    }

    private func field(number: UInt64, bytes: [UInt8]) -> [UInt8] {
        var result = varint((number << 3) | 2)
        result += varint(UInt64(bytes.count))
        result += bytes
        return result
    }

    private func varint(_ value: UInt64) -> [UInt8] {
        var value = value
        var bytes: [UInt8] = []
        repeat {
            var byte = UInt8(value & 0x7f)
            value >>= 7
            if value != 0 { byte |= 0x80 }
            bytes.append(byte)
        } while value != 0
        return bytes
    }
}
