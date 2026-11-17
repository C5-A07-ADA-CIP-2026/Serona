//
//  SeronaSchema.swift
//  Serona
//

import SwiftData

enum SeronaSchema {
    static let models: [any PersistentModel.Type] = [Resep.self, Proyek.self]

    static func makeContainer(inMemory: Bool = false) throws -> ModelContainer {
        try ModelContainer(
            for: Schema(models),
            configurations: ModelConfiguration(isStoredInMemoryOnly: inMemory)
        )
    }

    /// In-memory container for SwiftUI previews; failing to build one is a programmer error.
    @MainActor
    static func makePreviewContainer() -> ModelContainer {
        do {
            return try makeContainer(inMemory: true)
        } catch {
            fatalError("Could not build the preview container: \(error)")
        }
    }
}
