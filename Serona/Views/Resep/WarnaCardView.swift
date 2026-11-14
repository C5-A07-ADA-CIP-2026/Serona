//
//  WarnaCardView.swift
//  Serona
//
//  Created by Steffany Florence on 11/11/26.
//

import SwiftUI

struct WarnaCardView: View {
    let resep: Resep
    
    // Determines whether the color has been used in a project / has a color swatch preview.
    // In your logic, set this based on whether `resep.isUsed` or if `warnaHex` is set.
    var isUsedInBak: Bool {
        // Example check matching Image 1: "Marun" is unused / pending
        !resep.namaWarna.contains("Marun")
    }

    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let tileBackground = Color(red: 0.93, green: 0.93, blue: 0.93)

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            WarnaKotak(
                hex: isUsedInBak ? resep.warnaHex : nil,
                cornerRadius: 14,
                iconSize: 44
            )
            .aspectRatio(1, contentMode: .fit)

            // Recipe Color Name
            Text(resep.namaWarna)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(titleColor)
        }
        .padding(14)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 18))
        .shadow(color: Color.black.opacity(0.04), radius: 6, x: 0, y: 3)
    }
}

// MARK: - Previews

#Preview("Warna Card - Single States", traits: .landscapeLeft) {
    ZStack {
        Color(red: 0.98, green: 0.97, blue: 0.93)
            .ignoresSafeArea()
        
        HStack(alignment: .top, spacing: 20) {
            // Used in Bak Card (Color swatch visible)
            WarnaCardView(resep: .previewUsedSample)
                .frame(width: 220)
            
            // Unused in Bak Card (Placeholder / pending scan state)
            WarnaCardView(resep: .previewUnusedSample)
                .frame(width: 220)
        }
        .padding()
    }
}

// MARK: - Preview Helpers

private extension Resep {
    static var previewUsedSample: Resep {
        Resep(
            namaWarna: "Cokelat Bata",
            warnaHex: "#C0533E",
            air: 1000, kepekatan: 80, batasPH: 7
        )
    }
    
    static var previewUnusedSample: Resep {
        Resep(
            namaWarna: "Marun",
            warnaHex: "#800000",
            air: 1000, kepekatan: 80, batasPH: 7
        )
    }
}
