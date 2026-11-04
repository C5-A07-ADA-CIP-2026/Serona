//
//  QualityAlertSheetView.swift
//  Serona
//

import SwiftUI

/// "Perhatian": tells the user which reading fell below its limit and what to do.
struct QualityAlertSheetView: View {
    @Environment(\.dismiss) private var dismiss

    /// Space the navigation bar and the drag indicator take above the content.
    private static let barHeight: CGFloat = 64

    @State private var contentHeight: CGFloat = 480

    let alert: QualityAlert
    let onPerbaiki: () -> Void

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    Text("Kualitas Larutan Menurun")
                        .font(.title2.bold())
                        .multilineTextAlignment(.center)

                    RoundedRectangle(cornerRadius: 24)
                        .fill(Color(.systemGray4))
                        .frame(width: 196, height: 196)
                        .overlay {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.largeTitle)
                                .foregroundStyle(Color.peringatan)
                        }
                        .accessibilityHidden(true)

                    Text(alert.message)
                        .font(.callout)
                        .frame(maxWidth: .infinity, alignment: .leading)

                    Button {
                        onPerbaiki()
                        dismiss()
                    } label: {
                        Text("Perbaiki Larutan")
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.borderedProminent)
                    .controlSize(.large)
                }
                .padding(.horizontal, 24)
                .padding(.top, 8)
                .padding(.bottom, 24)
                .onGeometryChange(for: CGFloat.self) { $0.size.height } action: {
                    contentHeight = $0
                }
            }
            .scrollDisabled(true)
            .navigationTitle("Perhatian")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(role: .close) {
                        dismiss()
                    }
                }
            }
        }
        .presentationDetents([.height(contentHeight + Self.barHeight)])
        .presentationDragIndicator(.visible)
    }
}

/// The red banner under the readings while the solution is below a limit. Tapping it opens the repair guide.
struct LarutanMenurunBanner: View {
    var onTap: (() -> Void)?

    var body: some View {
        Button {
            onTap?()
        } label: {
            HStack {
                Text("Kualitas Larutan Menurun")
                Spacer()
                Image(systemName: "exclamationmark.circle.fill")
            }
            .font(.headline)
            .foregroundStyle(.white)
            .padding(12)
            .frame(maxWidth: .infinity)
            .background(Color.latarPeringatan, in: RoundedRectangle(cornerRadius: 10))
        }
        .buttonStyle(.plain)
        .disabled(onTap == nil)
        .accessibilityElement(children: .combine)
    }
}

#Preview {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QualityAlertSheetView(
                alert: QualityAlert(issue: .keduanya, message: MeasurementWarningTracker.bothMessage),
                onPerbaiki: {}
            )
        }
}
