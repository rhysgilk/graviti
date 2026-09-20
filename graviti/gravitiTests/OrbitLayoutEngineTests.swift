import XCTest
import SwiftUI
@testable import graviti

final class OrbitLayoutEngineTests: XCTestCase {
    func testLayoutKeepsPlanetsInsideFieldAndSeparated() throws {
        let items = (0..<6).map { index in
            OrbitItem(
                node: OrbitNode(name: "Node \(index)", level: .city, gravity: Double(100 - index * 12), saveCount: 8 - index),
                primaryColor: .blue,
                highlightColor: .white,
                driftX: index.isMultiple(of: 2) ? 4 : -4,
                driftY: 3,
                driftDurationX: 10,
                driftDurationY: 12
            )
        }
        let size = CGSize(width: 390, height: 700)
        let layout = OrbitLayoutEngine.layout(items: items, in: size)

        for item in items {
            let point = layout.position(for: item)
            let radius = layout.diameter(for: item) / 2
            XCTAssertGreaterThanOrEqual(point.x - radius, 0)
            XCTAssertLessThanOrEqual(point.x + radius, size.width)
            XCTAssertGreaterThanOrEqual(point.y - radius, 0)
            XCTAssertLessThanOrEqual(point.y + radius, size.height)
        }

        for first in 0..<(items.count - 1) {
            for second in (first + 1)..<items.count {
                let a = layout.position(for: items[first])
                let b = layout.position(for: items[second])
                let distance = hypot(a.x - b.x, a.y - b.y)
                let required = (layout.diameter(for: items[first]) + layout.diameter(for: items[second])) / 2
                XCTAssertGreaterThanOrEqual(distance + 1, required)
            }
        }
    }

    func testEmptyLayoutUsesStableFocusAndNoDrift() {
        let layout = OrbitLayoutEngine.layout(items: [], in: CGSize(width: 390, height: 700))
        XCTAssertTrue(layout.positions.isEmpty)
        XCTAssertTrue(layout.diameters.isEmpty)
        XCTAssertFalse(layout.allowsDrift)
        XCTAssertEqual(layout.focusPoint.x, 195, accuracy: 0.01)
    }

    func testTenDestinationFieldRemainsInsideBoundsAndSeparated() {
        let items = makeItems(count: 10)
        let size = CGSize(width: 390, height: 700)
        let layout = OrbitLayoutEngine.layout(items: items, in: size)

        assertValidLayout(layout, for: items, in: size)
    }

    func testLayoutIsDeterministicForTheSameRankedDestinations() {
        let items = makeItems(count: 10)
        let size = CGSize(width: 390, height: 700)

        let first = OrbitLayoutEngine.layout(items: items, in: size)
        let second = OrbitLayoutEngine.layout(items: items, in: size)

        XCTAssertEqual(first.allowsDrift, second.allowsDrift)
        for item in items {
            XCTAssertEqual(first.position(for: item).x, second.position(for: item).x, accuracy: 0.001)
            XCTAssertEqual(first.position(for: item).y, second.position(for: item).y, accuracy: 0.001)
            XCTAssertEqual(first.diameter(for: item), second.diameter(for: item), accuracy: 0.001)
        }
    }

    private func makeItems(count: Int) -> [OrbitItem] {
        (0..<count).map { index in
            OrbitItem(
                node: OrbitNode(
                    name: "Destination \(index)",
                    level: .city,
                    gravity: Double(100 - index * 7),
                    saveCount: 12 - index
                ),
                primaryColor: .blue,
                highlightColor: .white,
                driftX: index.isMultiple(of: 2) ? 5 : -5,
                driftY: index.isMultiple(of: 3) ? -4 : 4,
                driftDurationX: 10,
                driftDurationY: 12
            )
        }
    }

    private func assertValidLayout(
        _ layout: OrbitLayout,
        for items: [OrbitItem],
        in size: CGSize,
        file: StaticString = #filePath,
        line: UInt = #line
    ) {
        for item in items {
            let point = layout.position(for: item)
            let radius = layout.diameter(for: item) / 2
            XCTAssertGreaterThanOrEqual(point.x - radius, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(point.x + radius, size.width, file: file, line: line)
            XCTAssertGreaterThanOrEqual(point.y - radius, 0, file: file, line: line)
            XCTAssertLessThanOrEqual(point.y + radius, size.height, file: file, line: line)
        }

        for first in 0..<(items.count - 1) {
            for second in (first + 1)..<items.count {
                let a = layout.position(for: items[first])
                let b = layout.position(for: items[second])
                let distance = hypot(a.x - b.x, a.y - b.y)
                let required = (layout.diameter(for: items[first]) + layout.diameter(for: items[second])) / 2
                XCTAssertGreaterThanOrEqual(distance + 1, required, file: file, line: line)
            }
        }
    }
}
