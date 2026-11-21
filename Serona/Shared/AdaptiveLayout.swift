//
//  AdaptiveLayout.swift
//  Serona
//

import SwiftUI

/// Sizes grids and margins from the width they are given, so the same screen works on an iPhone and an iPad in
/// portrait and landscape.
enum AdaptiveLayout {
    /// Below this width (an iPhone in portrait) the side margins are tighter.
    static let compactWidthLimit: CGFloat = 500

    static func sidePadding(forWidth width: CGFloat) -> CGFloat {
        width < compactWidthLimit ? 16 : 24
    }

    /// How many columns of at least `minimumItemWidth` fit in `width`, kept within `limits`.
    static func columnCount(
        forWidth width: CGFloat,
        minimumItemWidth: CGFloat,
        spacing: CGFloat,
        limits: ClosedRange<Int>
    ) -> Int {
        let usable = width - 2 * sidePadding(forWidth: width)
        let fitting = Int((usable + spacing) / (minimumItemWidth + spacing))
        return min(limits.upperBound, max(limits.lowerBound, fitting))
    }

    static func gridColumns(
        forWidth width: CGFloat,
        minimumItemWidth: CGFloat,
        spacing: CGFloat,
        limits: ClosedRange<Int>
    ) -> [GridItem] {
        let count = columnCount(forWidth: width, minimumItemWidth: minimumItemWidth, spacing: spacing, limits: limits)
        return Array(repeating: GridItem(.flexible(), spacing: spacing), count: count)
    }
}
