import SwiftUI

struct BackgroundGradient: View {
    var body: some View {
        LinearGradient(
            colors: [
                Color(hex: "#FBEBC1"),
                Color(hex: "#F5D8CB"),
            ],
            startPoint: .top,
            endPoint: .bottom
        )
        .ignoresSafeArea()
    }
}
