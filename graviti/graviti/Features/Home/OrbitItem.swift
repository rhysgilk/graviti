import SwiftUI

// Temporary presentation data for a planet's appearance and motion.
struct OrbitItem: Identifiable {
    let node: OrbitNode

    let primaryColor: Color
    let highlightColor: Color

    let driftX: CGFloat
    let driftY: CGFloat

    let driftDurationX: Double
    let driftDurationY: Double

    var id: UUID { node.id }
}
