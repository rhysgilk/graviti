import SwiftUI

// Prototype geography for exercising semantic zoom until destination data is available.
enum SampleOrbitChildren {
    static func children(for parent: OrbitItem) -> [OrbitItem] {
        switch (parent.node.name, parent.node.level) {
        case ("Tokyo", .city):
            return tokyoAreas(color: parent.primaryColor, highlight: parent.highlightColor)
        case ("California", .stateProvince):
            return californiaCities(color: parent.primaryColor, highlight: parent.highlightColor)
        default:
            return []
        }
    }

    private static let tokyoNodes: [OrbitNode] = [
        OrbitNode(name: "Shinjuku", level: .district, gravity: 48, saveCount: 6),
        OrbitNode(name: "Shibuya", level: .district, gravity: 37, saveCount: 5),
        OrbitNode(name: "Asakusa", level: .neighborhood, gravity: 20, saveCount: 3)
    ]

    private static let californiaNodes: [OrbitNode] = [
        OrbitNode(name: "San Francisco", level: .city, gravity: 46, saveCount: 8),
        OrbitNode(name: "Los Angeles", level: .city, gravity: 35, saveCount: 6),
        OrbitNode(name: "San Diego", level: .city, gravity: 19, saveCount: 4)
    ]

    private static func tokyoAreas(color: Color, highlight: Color) -> [OrbitItem] {
        [
            OrbitItem(
                node: tokyoNodes[0],
                primaryColor: color, highlightColor: highlight,
                driftX: 5, driftY: -4, driftDurationX: 9, driftDurationY: 11
            ),
            OrbitItem(
                node: tokyoNodes[1],
                primaryColor: color, highlightColor: highlight,
                driftX: -4, driftY: 5, driftDurationX: 10, driftDurationY: 8
            ),
            OrbitItem(
                node: tokyoNodes[2],
                primaryColor: color, highlightColor: highlight,
                driftX: 4, driftY: 4, driftDurationX: 8, driftDurationY: 10
            )
        ]
    }

    private static func californiaCities(color: Color, highlight: Color) -> [OrbitItem] {
        [
            OrbitItem(
                node: californiaNodes[0],
                primaryColor: color, highlightColor: highlight,
                driftX: 5, driftY: -4, driftDurationX: 10, driftDurationY: 9
            ),
            OrbitItem(
                node: californiaNodes[1],
                primaryColor: color, highlightColor: highlight,
                driftX: -5, driftY: 4, driftDurationX: 9, driftDurationY: 11
            ),
            OrbitItem(
                node: californiaNodes[2],
                primaryColor: color, highlightColor: highlight,
                driftX: 4, driftY: 5, driftDurationX: 8, driftDurationY: 10
            )
        ]
    }
}
