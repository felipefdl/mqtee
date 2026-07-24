//
//  BrandTheme.swift
//  mqtee
//

import SwiftUI

enum BrandTheme {
    // MARK: - Brand Colors

    static let gradientStart = Color(red: 1.0, green: 0.72, blue: 0.0)
    static let gradientEnd = Color(red: 0.8, green: 0.27, blue: 0.0)

    static let brandGradient = LinearGradient(
        colors: [gradientStart, gradientEnd],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )

    // MARK: - Animation Curves

    static let springSnappy = Animation.spring(duration: 0.3, bounce: 0.2)
    static let springGentle = Animation.spring(duration: 0.5, bounce: 0.15)
    static let easeQuick = Animation.easeInOut(duration: 0.15)
}
