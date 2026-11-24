import SwiftData

protocol ModelPersisting {
    func insert(_ model: some PersistentModel)
    func delete(_ model: some PersistentModel)
    func save() throws
}

extension ModelPersisting {
    func insertAndSave(_ model: some PersistentModel) throws {
        insert(model)
        do {
            try save()
        } catch {
            delete(model)
            throw error
        }
    }
}

extension ModelContext: ModelPersisting {}
