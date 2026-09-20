//
//  GravitiWordmark.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

struct GravitiWordmark: View {
    enum Size {
        case small
        case large

        var fontSize: CGFloat {
            switch self {
            case .small: 26
            case .large: 54
            }
        }

        var smallDot: CGFloat {
            switch self {
            case .small: 4
            case .large: 8
            }
        }

        var largeDot: CGFloat {
            switch self {
            case .small: 7
            case .large: 13
            }
        }

        var dotOffset: CGFloat {
            switch self {
            case .small: -0.5
            case .large: -4
            }
        }
    }

    let size: Size
    var animated: Bool = false

    @Environment(\.accessibilityReduceMotion)
    private var reduceMotion

    @State
    private var alternate = false

    var body: some View {
        HStack(spacing: 0) {
            Text(verbatim: "grav")
                .font(GravitiTypography.display(size.fontSize))

            letterI(
                dotSize: firstDotSize,
                color: GravitiColors.iris
            )

            Text(verbatim: "t")
                .font(GravitiTypography.display(size.fontSize))

            letterI(
                dotSize: secondDotSize,
                color: GravitiColors.signalMint
            )
        }
        .foregroundStyle(.white)
        .environment(\.layoutDirection, .leftToRight)
        .fixedSize()
        .dynamicTypeSize(.large)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text(verbatim: "Graviti"))
        .onAppear {
            guard animated, !reduceMotion else { return }

            withAnimation(
                .easeInOut(duration: 0.9)
                    .repeatForever(autoreverses: true)
            ) {
                alternate = true
            }
        }
    }

    private func letterI(
        dotSize: CGFloat,
        color: Color
    ) -> some View {
        ZStack(alignment: .top) {
            Text(verbatim: "ı")
                .font(GravitiTypography.display(size.fontSize))

            Circle()
                .fill(color)
                .frame(width: dotSize, height: dotSize)
                .offset(y: size.dotOffset)
        }
    }

    private var firstDotSize: CGFloat {
        guard animated, !reduceMotion else {
            return size.smallDot
        }

        return alternate ? size.largeDot : size.smallDot
    }

    private var secondDotSize: CGFloat {
        guard animated, !reduceMotion else {
            return size.largeDot
        }

        return alternate ? size.smallDot : size.largeDot
    }
}

#Preview {
    ZStack {
        GravitiColors.appBackground
            .ignoresSafeArea()

        VStack(spacing: 60) {
            GravitiWordmark(
                size: .large,
                animated: true
            )

            GravitiWordmark(size: .small)
        }
    }
}
