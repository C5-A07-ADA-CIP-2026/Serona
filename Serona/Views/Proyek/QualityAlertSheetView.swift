//
//  QualityAlertSheetView.swift
//  Serona
//

import SwiftUI

/// "Perhatian": tells the user which reading fell below its limit and what to do.
struct QualityAlertSheetView: View {
    @Environment(\.dismiss) private var dismiss

    let alert: QualityAlert
    var bakName: String? = nil
    let onPerbaiki: () -> Void

    @ScaledMetric(relativeTo: .body) private var alertImageSize: CGFloat = 188
    @ScaledMetric(relativeTo: .body) private var closeButtonSize: CGFloat = 38
    @ScaledMetric(relativeTo: .body) private var sheetMinWidth: CGFloat = 440

    private var headingText: String {
        if let bakName, !bakName.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return "Kualitas \(bakName) Menurun"
        }
        return "Kualitas Larutan Menurun"
    }

    var body: some View {
        ZStack(alignment: .topTrailing) {
            VStack(spacing: 24) {
                Image("BakAlert")
                    .resizable()
                    .scaledToFit()
                    .frame(width: alertImageSize, height: alertImageSize)
                    .padding(.top, 12)
                    .accessibilityHidden(true)

                VStack(spacing: 8) {
                    Text(headingText)
                        .font(.title.bold())
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.center)

                    Text("Lakukan langkah-langkah berikut untuk perbaiki larutan")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                Button {
                    onPerbaiki()
                    dismiss()
                } label: {
                    Text("Mulai Perbaiki Larutan")
                        .font(.subheadline.bold())
                        .foregroundStyle(.white)
                        .padding(.horizontal, 36)
                        .padding(.vertical, 14)
                        .background(Color.oliveGreen, in: Capsule())
                }
                .buttonStyle(.plain)
                .padding(.top, 4)
            }
            .padding(.horizontal, 36)
            .padding(.vertical, 32)
            .frame(minWidth: sheetMinWidth)

            Button {
                dismiss()
            } label: {
                Image(systemName: "xmark")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                    .frame(width: closeButtonSize, height: closeButtonSize)
                    .background(Color.white, in: Circle())
                    .shadow(color: Color.black.opacity(0.08), radius: 6, x: 0, y: 2)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("Tutup")
            .padding(20)
        }
        .background(Color.white)
        .presentationSizing(.fitted)
        .presentationBackground(Color.white)
        .presentationDragIndicator(.hidden)
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

#Preview(traits: .landscapeLeft) {
    Color.clear
        .sheet(isPresented: .constant(true)) {
            QualityAlertSheetView(
                alert: QualityAlert(issue: .keduanya, message: MeasurementWarningTracker.bothMessage),
                bakName: "Bak 5",
                onPerbaiki: {}
            )
        }
}
