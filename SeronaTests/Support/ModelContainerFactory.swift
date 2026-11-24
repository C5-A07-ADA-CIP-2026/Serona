@testable import Serona
import SwiftData

@MainActor private var retainedContainers: [ModelContainer] = []

@MainActor
func makeTestContext() throws -> ModelContext {
    let container = try SeronaSchema.makeContainer(inMemory: true)
    retainedContainers.append(container)
    return ModelContext(container)
}

extension Resep {
    static func sample(
        namaWarna: String = "Ungu",
        warnaHex: String = "#4B0082",
        batasKepekatan: Double = 80,
        batasPH: Double = 7
    ) -> Resep {
        Resep(
            namaWarna: namaWarna,
            warnaHex: warnaHex,
            air: 1000,
            kepekatan: batasKepekatan,
            batasPH: batasPH
        )
    }
}
