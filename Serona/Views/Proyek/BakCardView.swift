//
//  BakCardView.swift
//  Serona
//
//  Created by Steffany Florence on 10/11/26.
//

import SwiftUI

enum BakCardStage {
    case active
    case activeWarning
    case disconnected
    case inactive
}

struct BakCardView: View {
    let proyek: Proyek
    var viewModel: ProyekDetailViewModel?
    var onMulaiPindai: (() -> Void)?
    var onSelesai: (() -> Void)?
    var onPerbaikiLarutan: (() -> Void)?
    var onQualityAlert: ((QualityAlert) -> Void)?

    var body: some View {
        if let viewModel {
            ObservedBakCardBody(
                proyek: proyek,
                viewModel: viewModel,
                onMulaiPindai: onMulaiPindai,
                onSelesai: onSelesai,
                onPerbaikiLarutan: onPerbaikiLarutan,
                onQualityAlert: onQualityAlert
            )
        } else {
            BakCardContent(
                proyek: proyek,
                viewModel: nil,
                onMulaiPindai: onMulaiPindai,
                onSelesai: onSelesai,
                onPerbaikiLarutan: onPerbaikiLarutan
            )
        }
    }
}

private struct ObservedBakCardBody: View {
    let proyek: Proyek
    @ObservedObject var viewModel: ProyekDetailViewModel
    var onMulaiPindai: (() -> Void)?
    var onSelesai: (() -> Void)?
    var onPerbaikiLarutan: (() -> Void)?
    var onQualityAlert: ((QualityAlert) -> Void)?

    private var currentStage: BakCardStage {
        guard proyek.status == .aktif else {
            return .inactive
        }

        let isDisconnected = switch viewModel.connectionState {
        case .disconnected, .failed:
            true
        case .ready, .connecting, .discovering, .reconnecting:
            false
        }

        let hasUnreadyError = viewModel.colorMeasurementError != nil && viewModel.connectionState != .ready
        if !viewModel.isScanning, isDisconnected || hasUnreadyError {
            return .disconnected
        }

        guard viewModel.isDataScanned else {
            return .inactive
        }

        let isLowConcentration = (viewModel.latestConcentration ?? 100) < proyek.batasKepekatan
        let isLowPH = (viewModel.latestWaterPH ?? 14) < proyek.batasPH
        let hasLiveAlert = viewModel.qualityAlert != nil || viewModel.currentIssue != nil
            || isLowConcentration || isLowPH
        return hasLiveAlert ? .activeWarning : .active
    }

    var body: some View {
        // Re-evaluate periodically so BLE disconnect/reconnect transitions update the card immediately.
        TimelineView(.periodic(from: .now, by: 1)) { context in
            let stage = currentStage

            BakCardContent(
                proyek: proyek,
                viewModel: viewModel,
                liveRevision: LiveRevision(measuredAt: viewModel.lastMeasurementAt, tick: context.date),
                onMulaiPindai: onMulaiPindai,
                onSelesai: onSelesai,
                onPerbaikiLarutan: onPerbaikiLarutan
            )
            .onAppear {
                if stage == .activeWarning {
                    if let existingAlert = viewModel.qualityAlert {
                        onQualityAlert?(existingAlert)
                    } else {
                        onQualityAlert?(makeFallbackAlert())
                    }
                }
            }
            .onChange(of: viewModel.qualityAlert) { _, newAlert in
                if let newAlert, stage != .disconnected {
                    onQualityAlert?(newAlert)
                }
            }
            .onChange(of: stage) { oldStage, newStage in
                if newStage == .activeWarning, oldStage != .activeWarning {
                    onQualityAlert?(viewModel.qualityAlert ?? makeFallbackAlert())
                }
            }
        }
    }

    private func makeFallbackAlert() -> QualityAlert {
        let isLowC = (viewModel.latestConcentration ?? 100) < proyek.batasKepekatan
        let isLowPH = (viewModel.latestWaterPH ?? 14) < proyek.batasPH

        let issue: QualityIssue
        let message: String
        switch (isLowC, isLowPH) {
        case (true, true):
            issue = .keduanya
            message = MeasurementWarningTracker.bothMessage
        case (true, false):
            issue = .kepekatan
            message = MeasurementWarningTracker.concentrationMessage(limit: proyek.batasKepekatan)
        case (false, true):
            issue = .phAir
            message = MeasurementWarningTracker.waterPHMessage(limit: proyek.batasPH)
        case (false, false):
            issue = viewModel.currentIssue ?? .keduanya
            message = MeasurementWarningTracker.bothMessage
        }
        return QualityAlert(issue: issue, message: message)
    }
}
