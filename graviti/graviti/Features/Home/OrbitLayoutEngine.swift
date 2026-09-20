import SwiftUI

struct OrbitLayout {
    let positions: [UUID: CGPoint]
    let diameters: [UUID: CGFloat]
    let focusPoint: CGPoint
    let allowsDrift: Bool

    func position(for item: OrbitItem) -> CGPoint {
        positions[item.id] ?? focusPoint
    }

    func diameter(for item: OrbitItem) -> CGFloat {
        diameters[item.id] ?? GravityScale.minimumDiameter
    }
}

enum OrbitLayoutEngine {
    // Rank-based starting points preserve the field's visual balance. They are
    // independent of destination identity; the solver moves them as needed.
    private static let preferredPoints: [UnitPoint] = [
        UnitPoint(x: 0.43, y: 0.30),
        UnitPoint(x: 0.79, y: 0.17),
        UnitPoint(x: 0.18, y: 0.51),
        UnitPoint(x: 0.80, y: 0.48),
        UnitPoint(x: 0.68, y: 0.68),
        UnitPoint(x: 0.30, y: 0.76)
    ]

    static func layout(items: [OrbitItem], in size: CGSize) -> OrbitLayout {
        let topInset = min(76, size.height * 0.16)
        let field = CGRect(
            x: 0,
            y: topInset,
            width: max(0, size.width),
            height: max(0, size.height - topInset - 20)
        )
        let focus = CGPoint(x: field.midX, y: field.minY + field.height * 0.35)

        guard !items.isEmpty else {
            return OrbitLayout(positions: [:], diameters: [:], focusPoint: focus, allowsDrift: false)
        }

        let ranked = items.sorted { OrbitNode.ranksBefore($0.node, $1.node) }
        let gravities = ranked.map(\.node.gravity)
        let minimumGravity = gravities.min() ?? 0
        let maximumGravity = gravities.max() ?? 1

        // Keep the normal scale and drift whenever the field accommodates them.
        // Compact screens can use the documented 58pt minimum, then pause drift.
        let attempts: [(scale: CGFloat, allowsDrift: Bool)] = [
            (1, true), (0.94, true), (0.88, true), (0.88, false)
        ]
        for (index, attempt) in attempts.enumerated() {
            let diameters = ranked.map {
                GravityScale.diameter(
                    for: $0.node.gravity,
                    minimumGravity: minimumGravity,
                    maximumGravity: maximumGravity
                ) * attempt.scale
            }
            let result = resolve(
                ranked,
                diameters: diameters,
                in: field,
                includeDrift: attempt.allowsDrift
            )
            if result.maximumOverlap <= 1 || index == attempts.count - 1 {
                return OrbitLayout(
                    positions: Dictionary(uniqueKeysWithValues: zip(ranked.map(\.id), result.points)),
                    diameters: Dictionary(uniqueKeysWithValues: zip(ranked.map(\.id), diameters)),
                    focusPoint: focus,
                    allowsDrift: attempt.allowsDrift
                )
            }
        }
        preconditionFailure("Layout attempts must not be empty")
    }

    private static func resolve(
        _ items: [OrbitItem],
        diameters: [CGFloat],
        in field: CGRect,
        includeDrift: Bool
    ) -> (points: [CGPoint], maximumOverlap: CGFloat) {
        let radii = zip(items, diameters).map { item, diameter in
            let drift = includeDrift ? max(abs(item.driftX), abs(item.driftY)) : 0
            return diameter / 2 + drift + 4
        }
        var points = items.indices.map { index in
            clamped(preferredPoint(at: index, in: field), radius: radii[index], in: field)
        }

        for _ in 0..<120 {
            var moved = false

            for first in 0..<max(0, items.count - 1) {
                for second in (first + 1)..<items.count {
                    var dx = points[second].x - points[first].x
                    var dy = points[second].y - points[first].y
                    var distance = sqrt(dx * dx + dy * dy)
                    let required = radii[first] + radii[second] + 6
                    let overlap = required - distance
                    guard overlap > 0.5 else { continue }

                    if distance < 0.001 {
                        let angle = CGFloat(second - first) * 2.399963
                        dx = cos(angle)
                        dy = sin(angle)
                        distance = 1
                    }

                    let firstShare = CGFloat(first + 1) / CGFloat(first + second + 2)
                    let firstMove = overlap * firstShare
                    let secondMove = overlap - firstMove
                    points[first].x -= dx / distance * firstMove
                    points[first].y -= dy / distance * firstMove
                    points[second].x += dx / distance * secondMove
                    points[second].y += dy / distance * secondMove
                    moved = true
                }
            }

            for index in points.indices {
                points[index] = clamped(points[index], radius: radii[index], in: field)
            }
            if !moved { break }
        }

        var maximumOverlap: CGFloat = 0
        for first in 0..<max(0, items.count - 1) {
            for second in (first + 1)..<items.count {
                let dx = points[second].x - points[first].x
                let dy = points[second].y - points[first].y
                let distance = sqrt(dx * dx + dy * dy)
                maximumOverlap = max(maximumOverlap, radii[first] + radii[second] + 6 - distance)
            }
        }
        return (points, maximumOverlap)
    }

    private static func preferredPoint(at index: Int, in field: CGRect) -> CGPoint {
        if index < preferredPoints.count {
            let point = preferredPoints[index]
            return CGPoint(
                x: field.minX + field.width * point.x,
                y: field.minY + field.height * point.y
            )
        }

        let angle = CGFloat(index - preferredPoints.count) * 2.399963 - .pi / 2
        let radius = min(0.42, 0.28 + CGFloat(index - preferredPoints.count) * 0.04)
        return CGPoint(
            x: field.midX + cos(angle) * field.width * radius,
            y: field.midY + sin(angle) * field.height * radius
        )
    }

    private static func clamped(_ point: CGPoint, radius: CGFloat, in field: CGRect) -> CGPoint {
        let minimumX = field.minX + radius
        let maximumX = field.maxX - radius
        let minimumY = field.minY + radius
        let maximumY = field.maxY - radius
        return CGPoint(
            x: minimumX <= maximumX ? min(max(point.x, minimumX), maximumX) : field.midX,
            y: minimumY <= maximumY ? min(max(point.y, minimumY), maximumY) : field.midY
        )
    }
}
