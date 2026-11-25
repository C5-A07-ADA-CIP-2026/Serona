//
//  DummyModels.swift
//  Serona
//
//  Created by Steffany Florence on 25/11/26.
//

import Foundation
import SwiftUI

enum DummyBakStage {
    case active
    case activeWarning
    case disconnected
    case inactive
}

enum DummyQualityIssue: String, Identifiable {
    case phAir
    case kepekatan
    case keduanya

    var id: String { rawValue }
}

enum DummyRepairStep: Int, CaseIterable {
    case air = 0
    case phAir = 1
    case kepekatan = 2
}

struct DummyNaptholEntry: Identifiable, Hashable {
    let id = UUID()
    var kodePewarna: String
    var beratGram: Int
}

struct DummyZatPembantuEntry: Identifiable, Hashable {
    let id = UUID()
    var jenisSoda: String
    var beratGram: Int
}

struct DummyResepItem: Identifiable, Hashable {
    let id = UUID()
    var namaWarna: String
    var warnaHex: String?
    var volumeAirLiter: Int
    var napthols: [DummyNaptholEntry]
    var zatPembantu: [DummyZatPembantuEntry]
    var batasKepekatan: Int
    var batasPH: Double

    var primaryKodePewarna: String {
        if let first = napthols.first {
            return "Napthol \(first.kodePewarna)"
        }
        return "Napthol AS"
    }

    var primaryKodeSoda: String {
        if let first = zatPembantu.first {
            return "Soda \(first.jenisSoda)"
        }
        return "Soda Abu"
    }
}

@Observable
final class DummyRepairGuideState {
    var currentStep: DummyRepairStep = .air
    var jumlahAir: Int = 0

    func reset() {
        currentStep = .air
        jumlahAir = 0
    }
}

@Observable
final class DummyBakItem: Identifiable {
    let id = UUID()
    var nama: String
    var isAktif: Bool
    var isTerhubung: Bool
    var namaWarna: String
    var warnaHex: String
    var namaPemesan: String
    var perangkatNama: String
    var jumlahAirLiter: Int
    var batasKepekatan: Int
    var batasPH: Double
    var kepekatan: Int
    var phAir: Double
    var kodeSoda: String
    var kodePewarna: String
    var hasShownAutoAlert: Bool = false
    var repairGuide = DummyRepairGuideState()

    init(
        nama: String,
        isAktif: Bool,
        isTerhubung: Bool,
        namaWarna: String = "-",
        warnaHex: String = "#8E8E93",
        namaPemesan: String = "-",
        perangkatNama: String = "-",
        jumlahAirLiter: Int = 0,
        batasKepekatan: Int = 90,
        batasPH: Double = 11.0,
        kepekatan: Int = 100,
        phAir: Double = 13.0,
        kodeSoda: String = "Soda Abu",
        kodePewarna: String = "Napthol AS"
    ) {
        self.nama = nama
        self.isAktif = isAktif
        self.isTerhubung = isTerhubung
        self.namaWarna = namaWarna
        self.warnaHex = warnaHex
        self.namaPemesan = namaPemesan
        self.perangkatNama = perangkatNama
        self.jumlahAirLiter = jumlahAirLiter
        self.batasKepekatan = batasKepekatan
        self.batasPH = batasPH
        self.kepekatan = kepekatan
        self.phAir = phAir
        self.kodeSoda = kodeSoda
        self.kodePewarna = kodePewarna
    }

    var stage: DummyBakStage {
        guard isAktif else { return .inactive }
        guard isTerhubung else { return .disconnected }
        return currentIssue != nil ? .activeWarning : .active
    }

    var isConcentrationLow: Bool {
        stage == .activeWarning && kepekatan < batasKepekatan
    }

    var isPHLow: Bool {
        stage == .activeWarning && phAir < batasPH
    }

    var currentIssue: DummyQualityIssue? {
        guard isAktif, isTerhubung else { return nil }
        switch (kepekatan < batasKepekatan, phAir < batasPH) {
        case (true, true): return .keduanya
        case (true, false): return .kepekatan
        case (false, true): return .phAir
        case (false, false): return nil
        }
    }

    func finishBak() {
        isAktif = false
        isTerhubung = false
        namaWarna = "-"
        warnaHex = "#8E8E93"
        namaPemesan = "-"
        perangkatNama = "-"
        jumlahAirLiter = 0
        kepekatan = 100
        phAir = 13.0
        hasShownAutoAlert = false
        repairGuide.reset()
    }
    
    @discardableResult
    func simulateLiveDecrease() -> Bool {
        guard isAktif, isTerhubung else { return false }
        
        let wasWarning = (stage == .activeWarning)
        
        // Randomly decrease concentration by 0 or 1% (clamped at 60%)
        let dropK = Int.random(in: 0 ... 1)
        kepekatan = max(60, kepekatan - dropK)
        
        // Randomly decrease pH by 0.0, 0.1, or 0.2 (clamped at 8.0)
        let dropPH = [0.0, 0.1, 0.2].randomElement() ?? 0.0
        let updatedPH = max(8.0, phAir - dropPH)
        phAir = (updatedPH * 10).rounded() / 10
        
        let isNowWarning = (stage == .activeWarning)
        return !wasWarning && isNowWarning
    }
}

enum SeronaTheme {
    static let oliveGreen = Color(red: 0.42, green: 0.50, blue: 0.04)
    static let oliveGreenText = Color(red: 0.34, green: 0.41, blue: 0.03)
    static let warningRed = Color(red: 0.87, green: 0.14, blue: 0.16)
    static let modalBackground = Color(red: 0.95, green: 0.95, blue: 0.97)
    static let backgroundGradient = LinearGradient(
        colors: [
            Color(red: 0.99, green: 0.96, blue: 0.89),
            Color(red: 0.97, green: 0.92, blue: 0.85)
        ],
        startPoint: .top,
        endPoint: .bottom
    )
}

enum DummySeedData {
    static func initialReseps() -> [DummyResepItem] {
        [
            DummyResepItem(
                namaWarna: "Marun",
                warnaHex: nil,
                volumeAirLiter: 2,
                napthols: [
                    DummyNaptholEntry(kodePewarna: "AS", beratGram: 100),
                    DummyNaptholEntry(kodePewarna: "ASG", beratGram: 100)
                ],
                zatPembantu: [
                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 100)
                ],
                batasKepekatan: 90,
                batasPH: 11.0
            ),
            DummyResepItem(
                namaWarna: "Ungu Tua",
                warnaHex: "#8D3B60",
                volumeAirLiter: 5,
                napthols: [
                    DummyNaptholEntry(kodePewarna: "ASB", beratGram: 150)
                ],
                zatPembantu: [
                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 120)
                ],
                batasKepekatan: 90,
                batasPH: 11.0
            ),
            DummyResepItem(
                namaWarna: "Ungu Muda",
                warnaHex: "#A44572",
                volumeAirLiter: 4,
                napthols: [
                    DummyNaptholEntry(kodePewarna: "ASD", beratGram: 110)
                ],
                zatPembantu: [
                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 95)
                ],
                batasKepekatan: 90,
                batasPH: 11.0
            ),
            DummyResepItem(
                namaWarna: "Merah Bata",
                warnaHex: "#A33240",
                volumeAirLiter: 5,
                napthols: [
                    DummyNaptholEntry(kodePewarna: "AS", beratGram: 140),
                    DummyNaptholEntry(kodePewarna: "ASOL", beratGram: 60)
                ],
                zatPembantu: [
                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 130)
                ],
                batasKepekatan: 90,
                batasPH: 11.0
            ),
//            DummyResepItem(
//                namaWarna: "Merah Anggur",
//                warnaHex: "#8F2D49",
//                volumeAirLiter: 5,
//                napthols: [
//                    DummyNaptholEntry(kodePewarna: "ASBS", beratGram: 165)
//                ],
//                zatPembantu: [
//                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 140)
//                ],
//                batasKepekatan: 90,
//                batasPH: 11.0
//            ),
//            DummyResepItem(
//                namaWarna: "Ungu Abu",
//                warnaHex: "#6D4F63",
//                volumeAirLiter: 3,
//                napthols: [
//                    DummyNaptholEntry(kodePewarna: "ASBO", beratGram: 90)
//                ],
//                zatPembantu: [
//                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 85)
//                ],
//                batasKepekatan: 90,
//                batasPH: 11.0
//            ),
//            DummyResepItem(
//                namaWarna: "Krem",
//                warnaHex: "#EB8F6A",
//                volumeAirLiter: 3,
//                napthols: [
//                    DummyNaptholEntry(kodePewarna: "ASG", beratGram: 75)
//                ],
//                zatPembantu: [
//                    DummyZatPembantuEntry(jenisSoda: "Abu", beratGram: 80)
//                ],
//                batasKepekatan: 90,
//                batasPH: 11.0
//            )
        ]
    }

    static func initialBaks() -> [DummyBakItem] {
        [
            DummyBakItem(
                nama: "Bak 1",
                isAktif: true,
                isTerhubung: true,
                namaWarna: "Merah Bata",
                warnaHex: "#A33240",
                namaPemesan: "Bu Wati",
                perangkatNama: "ESP 32 - A",
                jumlahAirLiter: 5,
                batasKepekatan: 90,
                batasPH: 11.0,
                kepekatan: 100,
                phAir: 13.0,
                kodeSoda: "Soda Abu",
                kodePewarna: "Napthol AS"
            ),
            DummyBakItem(
                nama: "Bak 2",
                isAktif: false,
                isTerhubung: false
            ),
//            DummyBakItem(
//                nama: "Bak 3",
//                isAktif: true,
//                isTerhubung: true,
//                namaWarna: "Ungu Tua",
//                warnaHex: "#8D3B60",
//                namaPemesan: "Bu Michelle",
//                perangkatNama: "ESP 32 - B",
//                jumlahAirLiter: 5,
//                batasKepekatan: 90,
//                batasPH: 11.0,
//                kepekatan: 99,
//                phAir: 13.0,
//                kodeSoda: "Soda Abu",
//                kodePewarna: "Napthol ASB"
//            ),
//            DummyBakItem(
//                nama: "Bak 4",
//                isAktif: true,
//                isTerhubung: true,
//                namaWarna: "Ungu Abu",
//                warnaHex: "#6D4F63",
//                namaPemesan: "Bu Fanny",
//                perangkatNama: "ESP 32 - C",
//                jumlahAirLiter: 3,
//                batasKepekatan: 90,
//                batasPH: 11.0,
//                kepekatan: 100,
//                phAir: 12.0,
//                kodeSoda: "Soda Abu",
//                kodePewarna: "Napthol ASBO"
//            ),
//            DummyBakItem(
//                nama: "Bak 3",
//                isAktif: true,
//                isTerhubung: true,
//                namaWarna: "Krem",
//                warnaHex: "#EB8F6A",
//                namaPemesan: "Bu Fanny",
//                perangkatNama: "ESP 32 - D",
//                jumlahAirLiter: 3,
//                batasKepekatan: 90,
//                batasPH: 11.0,
//                kepekatan: 87,
//                phAir: 10.0,
//                kodeSoda: "Soda Abu",
//                kodePewarna: "Napthol ASG"
//            ),
//            DummyBakItem(
//                nama: "Bak 6",
//                isAktif: true,
//                isTerhubung: true,
//                namaWarna: "Ungu Tua",
//                warnaHex: "#8D3B60",
//                namaPemesan: "Bu Michelle",
//                perangkatNama: "ESP 32 - E",
//                jumlahAirLiter: 5,
//                batasKepekatan: 90,
//                batasPH: 11.0,
//                kepekatan: 98,
//                phAir: 13.0,
//                kodeSoda: "Soda Abu",
//                kodePewarna: "Napthol ASB"
//            )
        ]
    }
}

extension Color {
    init(dummyHex hex: String) {
        let cleaned = hex.trimmingCharacters(in: CharacterSet.alphanumerics.inverted)
        var int: UInt64 = 0
        Scanner(string: cleaned).scanHexInt64(&int)
        let r = Double((int >> 16) & 0xFF) / 255.0
        let g = Double((int >> 8) & 0xFF) / 255.0
        let b = Double(int & 0xFF) / 255.0
        self.init(red: r, green: g, blue: b)
    }
}
