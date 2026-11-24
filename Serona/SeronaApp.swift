import SwiftData
import SwiftUI

@main
struct SeronaApp: App {
    var body: some Scene {
        WindowGroup {
            ContentView()
        }
        .modelContainer(for: SeronaSchema.models)
    }
}
