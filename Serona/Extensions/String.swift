import Foundation

extension String {
    var tidakKosong: Bool {
        !trimmingCharacters(in: .whitespaces).isEmpty
    }
}
