//
//  ProyekAlertTargets.swift
//  Serona
//

import Foundation

struct ProyekRepairTarget: Identifiable {
    let id: UUID
    let proyek: Proyek
    let viewModel: ProyekDetailViewModel
    let issue: QualityIssue
}

struct ProyekQualityAlertTarget: Identifiable {
    let id: UUID
    let proyek: Proyek
    let viewModel: ProyekDetailViewModel
    let alert: QualityAlert
}
