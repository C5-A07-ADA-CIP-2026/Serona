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
            if isUsedInBak {
                // Color Swatch Block
                RoundedRectangle(cornerRadius: 14)
                    .fill(Color(hex: resep.warnaHex))
                    .frame(height: 160)
            } else {
                // Placeholder Image Block for Unused Colors
                ZStack {
                    RoundedRectangle(cornerRadius: 14)
                        .fill(tileBackground)
                        .frame(height: 160)

                    Image(systemName: "photo.badge.exclamationmark")
                        .font(.system(size: 44))
                        .foregroundStyle(Color.gray.opacity(0.5))
                }
            }

            // Recipe Color Name
            Text(resep.namaWarna)
                .font(.system(size: 18, weight: .bold))
                .foregroundStyle(titleColor)

            // Subtitle Note for Unused Colors
            if !isUsedInBak {
                Text("*warna akan muncul ketika sudah dipakai pada bak warna")
                    .font(.system(size: 11))
                    .foregroundStyle(Color.gray.opacity(0.8))
                    .lineLimit(2)
            }
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
