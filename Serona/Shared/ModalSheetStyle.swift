//
//  ModalSheetStyle.swift
//  Serona
//

import SwiftUI

extension View {
    /// Form-sized white sheet without a drag indicator. Skipped when the view is pushed inside a sheet's
    /// `NavigationStack`, so the pushed screen does not change how the surrounding sheet is presented.
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
