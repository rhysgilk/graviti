//
//  GravitiTypography.swift
//  graviti
//
//  Created by Rhys Gilkenson on 9/17/26.
//

import SwiftUI

enum GravitiTypography {
    static func display(_ size: CGFloat) -> Font {
        .custom("Sora-SemiBold", size: size)
    }

    static func displayRegular(_ size: CGFloat) -> Font {
        .custom("Sora-Regular", size: size)
    }
}
