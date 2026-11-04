//
//  BarisAwalView.swift
//  Serona
//

import SwiftUI

/// An "awal" row whose value comes from the live reading right above it.
/// Not set yet: a small "Tetapkan" button (or "Menunggu sensor…" while there is no reading) takes the value's place.
/// Set: the value, with a small button to measure again. Stacked at accessibility sizes, like `BarisInfo`.
struct BarisAwalView: View {
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize

    let judul: String
    let nilai: String
    let isSet: Bool
    let canSet: Bool
    let onSet: () -> Void
    let onReset: () -> Void

    var body: some View {
        let layout = dynamicTypeSize.isAccessibilitySize
            ? AnyLayout(VStackLayout(alignment: .leading, spacing: 4))
            : AnyLayout(HStackLayout())
        layout {
            Text(judul)

            if !dynamicTypeSize.isAccessibilitySize {
                Spacer()
            }

            trailing
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .contain)
    }

    @ViewBuilder
    private var trailing: some View {
        if isSet {
            HStack(spacing: 4) {
                Text(nilai)
                    .monospacedDigit()
                Button(action: onReset) {
                    Image(systemName: "arrow.counterclockwise")
                        .frame(minWidth: 44, minHeight: 44)
                        .contentShape(.rect)
                }
                .buttonStyle(.plain)
                .foregroundStyle(.tint)
                .accessibilityLabel("Ukur ulang \(judul.lowercased())")
            }
        } else if canSet {
            Button("Tetapkan", action: onSet)
                .buttonStyle(.bordered)
                .buttonBorderShape(.capsule)
                .accessibilityLabel("Tetapkan sebagai \(judul.lowercased())")
        } else {
            HStack(spacing: 8) {
                ProgressView()
                    .controlSize(.small)
                Text("Menunggu sensor…")
                    .font(.subheadline)
            }
            .accessibilityElement(children: .combine)
        }
    }
}

#Preview("Siap ditetapkan") {
    BarisAwalView(judul: "Kepekatan Warna Awal", nilai: "—", isSet: false, canSet: true, onSet: {}, onReset: {})
        .padding(24)
}

#Preview("Menunggu sensor") {
    BarisAwalView(judul: "pH Air Awal", nilai: "—", isSet: false, canSet: false, onSet: {}, onReset: {})
        .padding(24)
}

#Preview("Sudah ditetapkan") {
    BarisAwalView(judul: "Kepekatan Warna Awal", nilai: "100%", isSet: true, canSet: false, onSet: {}, onReset: {})
        .padding(24)
}

#Preview("Accessibility size") {
    VStack(alignment: .leading, spacing: 16) {
        BarisAwalView(judul: "Kepekatan Warna Awal", nilai: "—", isSet: false, canSet: true, onSet: {}, onReset: {})
        BarisAwalView(judul: "pH Air Awal", nilai: "10", isSet: true, canSet: false, onSet: {}, onReset: {})
    }
    .padding(24)
    .dynamicTypeSize(.accessibility5)
}
