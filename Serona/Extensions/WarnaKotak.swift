//
//  WarnaKotak.swift
//  Serona
//
//  Created by Dina on 14/11/26.
//

import SwiftUI

struct WarnaKotak: View {
    let hex: String?
    var cornerRadius: CGFloat = 12
    var iconSize: CGFloat = 32
    
    var body: some View {
        RoundedRectangle(cornerRadius: cornerRadius)
            .fill(Color(hex: hex) ?? Color.gray.opacity(0.2))
            .overlay {
                if Color(hex: hex) == nil {
                    VStack(spacing: 8) {
                        Image(systemName: "photo.badge.exclamationmark")
                            .font(.system(size: iconSize))
                            .foregroundStyle(Color.gray)
                        
                        Text("*warna akan muncul ketika sudah dipakai pada bak pewarna")
                            .font(.subheadline)
                            .foregroundStyle(Color.gray)
                            .multilineTextAlignment(.center)
                    }
                    .padding(12)
                }
            }
    }
}
