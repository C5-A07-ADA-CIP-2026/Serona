import SwiftUI

extension View {
    @ViewBuilder
    func modalSheetStyle(isEnabled: Bool = true) -> some View {
        if isEnabled {
            presentationSizing(.form)
                .presentationBackground(Color.white)
                .presentationDragIndicator(.hidden)
        } else {
            self
        }
    }
}
