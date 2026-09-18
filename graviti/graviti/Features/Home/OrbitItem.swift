import SwiftUI

// Temporary presentation data for a planet's position, appearance, and motion.
struct OrbitItem: Identifiable {
    let node: OrbitNode

    let x: CGFloat
    let y: CGFloat

    let primaryColor: Color
    let highlightColor: Color

    let driftX: CGFloat
    let driftY: CGFloat

    let driftDurationX: Double
    let driftDurationY: Double

    var id: UUID { node.id }
}
