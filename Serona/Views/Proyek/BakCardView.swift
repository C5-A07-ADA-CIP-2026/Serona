//
//  BakCardView.swift
//  Serona
//
//  Created by Steffany Florence on 10/11/26.
//

import SwiftUI

struct BakCardView: View {
    let proyek: Proyek

    // Sample data check: determine if the quality alert should be shown
    var hasQualityAlert: Bool {
        proyek.status == .aktif && proyek.nama.contains("Merah Ungu")
    }

    // Colors matching
    private let titleColor = Color(red: 0.38, green: 0.15, blue: 0.15)
    private let alertRed = Color(red: 0.98, green: 0.28, blue: 0.28)
    private let tileBackground = Color(red: 0.95, green: 0.96, blue: 0.93)
    private let oliveGreen = Color(red: 0.35, green: 0.42, blue: 0.25)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            // Card Title
            Text(proyek.nama)
                .font(.system(size: 22, weight: .bold))
                .foregroundStyle(titleColor)

            // Quality Alert Banner (Red Capsule)
            if hasQualityAlert {
                HStack {
                    Text("Kualitas Larutan Menurun")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.system(size: 16))
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(alertRed)
                .clipShape(Capsule())
            }

            // Stat Boxes Grid
            HStack(spacing: 12) {
                // Kepekatan Box
                statTile(
                    icon: "allergens", // Bottle/flask icon representation
                    title: "Kepekatan",
                    value: "94%"
                )

                // pH Air Box
                statTile(
                    icon: "drop",
                    title: "pH Air",
                    value: "12"
                )
            }
        }
        .padding(20)
        .background(Color.white)
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .overlay(
            RoundedRectangle(cornerRadius: 20)
                .stroke(hasQualityAlert ? alertRed : Color.clear, lineWidth: hasQualityAlert ? 2.5 : 0)
        )
        .shadow(color: Color.black.opacity(0.04), radius: 8, x: 0, y: 4)
    }

    // Metric Tile View
    private func statTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.system(size: 14))
                Text(title)
                    .font(.system(size: 14, weight: .medium))
            }
            .foregroundStyle(oliveGreen)

            Text(value)
                .font(.system(size: 36, weight: .bold))
                .foregroundStyle(hasQualityAlert ? alertRed : titleColor)
        }
        .frame(maxWidth: .infinity, alignment: .center)
        .padding(14)
        .background(tileBackground)
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }
}

// MARK: - Previews

#Preview("Bak Card - Single States", traits: .landscapeLeft) {
    ZStack {
        Color(red: 0.98, green: 0.97, blue: 0.93)
            .ignoresSafeArea()

        HStack(alignment: .top, spacing: 20) {
            // Alert State Card
            BakCardView(proyek: .previewAlertSample)
                .frame(width: 320)

            // Normal State Card
            BakCardView(proyek: .previewNormalSample)
                .frame(width: 320)
        }
        .padding()
    }
}

#Preview("Bak Cards Grid (iPad Layout)", traits: .landscapeLeft) {
    ZStack {
        Color(red: 0.98, green: 0.97, blue: 0.93)
            .ignoresSafeArea()

        LazyVGrid(
            columns: [
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20),
                GridItem(.flexible(), spacing: 20)
            ],
            spacing: 20
        ) {
            BakCardView(proyek: .previewAlertSample)
            BakCardView(proyek: .previewAlertSample)
            BakCardView(proyek: .previewAlertSample)
            BakCardView(proyek: .previewNormalSample)
            BakCardView(proyek: .previewAlertSample)
            BakCardView(proyek: .previewBataSample)
        }
        .padding(24)
    }
}

// MARK: - Preview Helpers

private extension Proyek {
    static var previewAlertSample: Proyek {
        Proyek(
            nama: "Bak Merah Ungu",
            perangkatNama: "ESP 32",
            resep: Resep(
                namaWarna: "Merah Ungu", warnaHex: "#B50202",
                air: 1000, kepekatan: 80, batasPH: 7
            ),
            jumlahKain: 2
        )
    }

    static var previewNormalSample: Proyek {
        Proyek(
            nama: "Bak Marun",
            perangkatNama: "ESP 32",
            resep: Resep(
                namaWarna: "Marun", warnaHex: "#800000",
                air: 1000, kepekatan: 80, batasPH: 7
            ),
            jumlahKain: 1
        )
    }

    static var previewBataSample: Proyek {
        Proyek(
            nama: "Bak Merah Bata",
            perangkatNama: "ESP 32",
            resep: Resep(
                namaWarna: "Merah Bata", warnaHex: "#A52A2A",
                air: 1000, kepekatan: 80, batasPH: 7
            ),
            jumlahKain: 3
        )
    }
}
