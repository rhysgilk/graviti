//
//  OrbitDriftModifier.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct OrbitDriftModifier: ViewModifier {
    let xDistance: CGFloat
    let yDistance: CGFloat
    let xDuration: Double
    let yDuration: Double
    let isActive: Bool

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var moveX = false

    @State
    private var moveY = false

    func body(content: Content) -> some View {
        content
            .offset(
                x: reduceMotion || !isActive
                    ? 0
                    : (moveX ? xDistance : 0)
            )
            .animation(
                reduceMotion || !isActive
                    ? nil
                    : .easeInOut(duration: xDuration)
                        .repeatForever(autoreverses: true),
                value: moveX
            )
            .offset(
                y: reduceMotion || !isActive
                    ? 0
                    : (moveY ? yDistance : 0)
            )
            .animation(
                reduceMotion || !isActive
                    ? nil
                    : .easeInOut(duration: yDuration)
                        .repeatForever(autoreverses: true),
                value: moveY
            )
            .onAppear {
                startMotion()
            }
            .onChange(of: reduceMotion) { _, isReduced in
                if isReduced {
                    moveX = false
                    moveY = false
                } else {
                    startMotion()
                }
            }
            .onChange(of: isActive) { _, active in
                if active {
                    startMotion()
                } else {
                    moveX = false
                    moveY = false
                }
            }
    }

    private func startMotion() {
        guard !reduceMotion && isActive else {
            return
        }

        moveX = true
        moveY = true
    }
}

extension View {
    func orbitDrift(
        x: CGFloat,
        y: CGFloat,
        xDuration: Double,
        yDuration: Double,
        isActive: Bool = true
    ) -> some View {
        modifier(
            OrbitDriftModifier(
                xDistance: x,
                yDistance: y,
                xDuration: xDuration,
                yDuration: yDuration,
                isActive: isActive
            )
        )
    }
}
