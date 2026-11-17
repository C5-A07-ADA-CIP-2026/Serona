//
//  TambahProyekView+Previews.swift
//  Serona
//

import SwiftData
import SwiftUI

// MARK: - Previews

#Preview("Tambah Proyek Sheet", traits: .landscapeLeft) {
    BackgroundGradient()
        .sheet(isPresented: .constant(true)) {
            TambahProyekView(bakTitle: "Bak 1")
        }
        .modelContainer(for: SeronaSchema.models, inMemory: true)
}
