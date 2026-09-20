import Foundation

// A read-only summary of the explicit Gravity Field shown on Home.
struct HomeInsight {
    let leadingDestination: OrbitNode
    let destinationCount: Int

    init?(nodes: [OrbitNode]) {
        guard let leader = nodes.sorted(by: OrbitNode.ranksBefore).first else {
            return nil
        }
        leadingDestination = leader
        destinationCount = nodes.count
    }
}
