@testable import Serona
import SwiftData
import Testing

@Suite("ModelPersisting insertAndSave")
@MainActor
struct ModelPersistingTests {
    @Test("Inserts the model and then saves")
    func insertAndSaveHappyPath() throws {
        let persistence = RecordingModelPersistence()
        let resep = Resep.sample()

        try persistence.insertAndSave(resep)

        #expect(persistence.events == [.insert, .save])
        #expect(persistence.insertedModels.count == 1)
        #expect(isSameModel(persistence.insertedModels[0], resep))
        #expect(persistence.deletedModels.isEmpty)
    }

    @Test("A failed save deletes the model again and rethrows")
    func insertAndSaveRollsBackOnFailure() throws {
        let persistence = RecordingModelPersistence()
        persistence.saveError = StubSaveError()
        let resep = Resep.sample()

        #expect(throws: StubSaveError.self) {
            try persistence.insertAndSave(resep)
        }

        #expect(persistence.events == [.insert, .save, .delete])
        #expect(isSameModel(persistence.deletedModels[0], resep))
    }

    @Test("ModelContext is a ModelPersisting and stores the model")
    func modelContextConforms() throws {
        let context = try makeTestContext()
        let persistence: some ModelPersisting = context

        try persistence.insertAndSave(Resep.sample())

        #expect(try context.fetch(FetchDescriptor<Resep>()).count == 1)
    }
}
