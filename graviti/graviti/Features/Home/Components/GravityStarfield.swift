import SwiftUI

struct GravityStarfield: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        TimelineView(.animation(minimumInterval: 1 / 20, paused: reduceMotion)) { timeline in
            Canvas { context, size in
                let time = timeline.date.timeIntervalSinceReferenceDate
                for star in Star.field {
                    let center = CGPoint(x: star.x * size.width, y: star.y * size.height)
                    let opacity = reduceMotion ? star.restingOpacity : star.opacity(at: time)
                    var starContext = context
                    starContext.opacity = opacity
                    if star.isSparkle {
                        starContext.fill(
                            sparklePath(center: center, radius: star.radius),
                            with: .color(star.color)
                        )
                    } else {
                        let diameter = star.radius * 2
                        starContext.fill(
                            Path(ellipseIn: CGRect(
                                x: center.x - star.radius,
                                y: center.y - star.radius,
                                width: diameter,
                                height: diameter
                            )),
                            with: .color(star.color)
                        )
                    }
                }
            }
        }
        .allowsHitTesting(false)
        .accessibilityHidden(true)
    }

    private func sparklePath(center: CGPoint, radius: CGFloat) -> Path {
        var path = Path()
        path.move(to: CGPoint(x: center.x, y: center.y - radius * 1.7))
        path.addLine(to: CGPoint(x: center.x + radius * 0.34, y: center.y - radius * 0.34))
        path.addLine(to: CGPoint(x: center.x + radius * 1.15, y: center.y))
        path.addLine(to: CGPoint(x: center.x + radius * 0.34, y: center.y + radius * 0.34))
        path.addLine(to: CGPoint(x: center.x, y: center.y + radius * 1.7))
        path.addLine(to: CGPoint(x: center.x - radius * 0.34, y: center.y + radius * 0.34))
        path.addLine(to: CGPoint(x: center.x - radius * 1.15, y: center.y))
        path.addLine(to: CGPoint(x: center.x - radius * 0.34, y: center.y - radius * 0.34))
        path.closeSubpath()
        return path
    }
}

private struct Star {
    let x: CGFloat
    let y: CGFloat
    let radius: CGFloat
    let phase: Double
    let duration: Double
    let restingOpacity: Double
    let isSparkle: Bool
    let isYellow: Bool

    var color: Color {
        isYellow
            ? Color(red: 1, green: 0.86, blue: 0.28)
            : .white
    }

    func opacity(at time: TimeInterval) -> Double {
        let wave = (sin((time / duration + phase) * .pi * 2) + 1) / 2
        return restingOpacity * 0.42 + wave * restingOpacity * 0.78
    }

    static let field: [Star] = {
        var state: UInt64 = 0x6772_6176_6974_6901
        func unit() -> Double {
            state = state &* 6_364_136_223_846_793_005 &+ 1_442_695_040_888_963_407
            return Double(state >> 11) / Double(UInt64.max >> 11)
        }

        return (0..<38).map { index in
            Star(
                x: CGFloat(0.035 + unit() * 0.93),
                y: CGFloat(0.08 + unit() * 0.83),
                radius: CGFloat(0.7 + unit() * (index.isMultiple(of: 6) ? 2.2 : 1.15)),
                phase: unit(),
                duration: 2.6 + unit() * 3.8,
                restingOpacity: 0.34 + unit() * 0.38,
                isSparkle: index.isMultiple(of: 6),
                isYellow: index.isMultiple(of: 5)
            )
        }
    }()
}

#Preview {
    ZStack {
        GravitiColors.appBackground
        GravityStarfield()
    }
    .ignoresSafeArea()
}
