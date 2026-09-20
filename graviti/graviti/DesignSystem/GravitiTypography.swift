//
//  GravitiTypography.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

enum GravitiTypography {
    static let largeTitle = Font.custom("Sora-SemiBold", size: 34, relativeTo: .largeTitle)
    static let title = Font.custom("Sora-SemiBold", size: 28, relativeTo: .title)
    static let title2 = Font.custom("Sora-SemiBold", size: 22, relativeTo: .title2)
    static let title3 = Font.custom("Sora-SemiBold", size: 20, relativeTo: .title3)
    static let headline = Font.custom("Sora-SemiBold", size: 17, relativeTo: .headline)
    static let body = Font.custom("Sora-Regular", size: 17, relativeTo: .body)
    static let subheadline = Font.custom("Sora-Regular", size: 15, relativeTo: .subheadline)
    static let subheadlineSemibold = Font.custom("Sora-SemiBold", size: 15, relativeTo: .subheadline)
    static let caption = Font.custom("Sora-Regular", size: 12, relativeTo: .caption)
    static let captionSemibold = Font.custom("Sora-SemiBold", size: 12, relativeTo: .caption)

    static func display(_ size: CGFloat) -> Font {
        .custom("Sora-SemiBold", size: size)
    }

    static func displayRegular(_ size: CGFloat) -> Font {
        .custom("Sora-Regular", size: size)
    }
}
