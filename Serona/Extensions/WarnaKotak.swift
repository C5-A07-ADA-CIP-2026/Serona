//
//  WarnaKotak.swift
//  Serona
//
//  Created by Dina on 14/11/26.
//

import SwiftUI

struct WarnaKotak: View {
    let hex: String?
    var cornerRadius: CGFloat = 12
    @ScaledMetric(relativeTo: .largeTitle) var iconSize: CGFloat = 32
    /// For wide, short strips: the placeholder lays out icon and text side by side instead of stacked.
    var isCompact = false

    private static let placeholderText = "Warna akan muncul setelah digunakan"

    var body: some View {
        if isCompact, Color(hex: hex) == nil {
            // The text decides the height here, so it wraps instead of being cut off on narrow screens.
            compactPlaceholder
                .frame(maxWidth: .infinity, minHeight: 44, alignment: .leading)
                .background(Color.gray.opacity(0.2), in: RoundedRectangle(cornerRadius: cornerRadius))
        } else {
            RoundedRectangle(cornerRadius: cornerRadius)
                .fill(Color(hex: hex) ?? Color.gray.opacity(0.2))
                .overlay {
                    if Color(hex: hex) == nil {
                        stackedPlaceholder
                    }
                }
        }
    }

    private var stackedPlaceholder: some View {
        VStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.system(size: iconSize))
                .foregroundStyle(Color.gray)

            Text(Self.placeholderText)
                .font(.subheadline)
                .foregroundStyle(Color.gray)
                .multilineTextAlignment(.center)
                .lineLimit(3)
                .minimumScaleFactor(0.7)
        }
        .padding(12)
    }

    private var compactPlaceholder: some View {
        HStack(spacing: 8) {
            Image(systemName: "photo")
                .font(.footnote)
                .foregroundStyle(Color.gray)

            Text(Self.placeholderText)
                .font(.footnote)
                .foregroundStyle(Color.gray)
                .multilineTextAlignment(.leading)
        }
        .padding(.vertical, 8)
        // Leave room for the remove button that sits on the trailing edge.
        .padding(.leading, 12)
        .padding(.trailing, 44)
    }
}
