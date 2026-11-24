@MainActor
func waitUntil(
    timeout: Duration = .seconds(2),
    interval: Duration = .milliseconds(5),
    _ condition: @MainActor () -> Bool
) async -> Bool {
    let clock = ContinuousClock()
    let deadline = clock.now.advanced(by: timeout)
    while !condition() {
        if clock.now >= deadline {
            return false
        }
        try? await Task.sleep(for: interval)
    }
    return true
}
