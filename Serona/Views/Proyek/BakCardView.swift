//
//  BakCardView.swift
//  Serona
//
//  Created by Steffany Florence on 10/11/26.
//

import SwiftUI

struct BakCardView: View {
    let proyek: Proyek
    var viewModel: ProyekDetailViewModel?

    var hasQualityAlert: Bool {
        let isLiveAlert = (viewModel?.qualityAlert != nil || viewModel?.currentIssue != nil)
        let isSampleAlert = (proyek.status == .aktif && proyek.nama.contains("Merah Ungu"))
        return isLiveAlert || isSampleAlert
    }

    var kepekatanDisplay: String {
        if let viewModel, let c = viewModel.latestConcentration {
            return String(format: "%.0f%%", c)
        }
        return "94%"
    }

    var phDisplay: String {
        if let viewModel, let ph = viewModel.latestWaterPH {
            return String(format: "%.0f", ph)
        }
        return "12"
    }

    private let titleColor = Color("titleColor")
    private let oliveGreen = Color("oliveGreen")
    private let alertRed = Color(red: 0.98, green: 0.28, blue: 0.28)
    private let tileBackground = Color(red: 0.95, green: 0.96, blue: 0.93)

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text(proyek.nama)
                .font(.title2.bold())
                .foregroundStyle(titleColor)

            if hasQualityAlert {
                HStack {
                    Text("Kualitas Larutan Menurun")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.white)

                    Spacer()

                    Image(systemName: "exclamationmark.circle.fill")
                        .font(.callout)
                        .foregroundStyle(.white)
                }
                .padding(.horizontal, 14)
                .padding(.vertical, 8)
                .background(alertRed)
                .clipShape(Capsule())
            }

            HStack(spacing: 12) {
                statTile(
                    icon: "allergens",
                    title: "Kepekatan",
                    value: kepekatanDisplay
                )

                statTile(
                    icon: "drop",
                    title: "pH Air",
                    value: phDisplay
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

    private func statTile(icon: String, title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.subheadline)
                Text(title)
                    .font(.subheadline.weight(.medium))
            }
            .foregroundStyle(oliveGreen)

            Text(value)
                .font(.largeTitle.bold())
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
        BackgroundGradient()

        HStack(alignment: .top, spacing: 20) {
            BakCardView(proyek: .previewAlertSample)
                .frame(width: 320)

            BakCardView(proyek: .previewNormalSample)
                .frame(width: 320)
        }
        .padding()
    }
}

#Preview("Bak Cards Grid (iPad Layout)", traits: .landscapeLeft) {
    ZStack {
        Color("backgroundColor")
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
