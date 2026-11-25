//
//  MainTabView.swift
//  Serona
//
//  Created by Steffany Florence on 25/11/26.
//

import Combine
import SwiftUI

enum SeronaTab: Int, CaseIterable {
    case bakWarna = 0
    case resepWarna = 1

    var title: String {
        switch self {
        case .bakWarna: "Bak Warna"
        case .resepWarna: "Resep Warna"
        }
    }
}

struct MainTabView: View {
    @State private var selectedTab: SeronaTab = .bakWarna
    @State private var reseps: [DummyResepItem] = DummySeedData.initialReseps()
    @State private var baks: [DummyBakItem] = DummySeedData.initialBaks()

    // Modal & alert states
    @State private var setupTargetBak: DummyBakItem?
    @State private var isAddingNewResep = false
    @State private var editingResep: DummyResepItem?
    @State private var activeAlertBak: DummyBakItem?
    @State private var queuedAlertBaks: [DummyBakItem] = []
    @State private var repairTargetBak: DummyBakItem?

    // 1. Live sensor fluctuation timer
    private let liveSensorTimer = Timer.publish(every: 2.5, on: .main, in: .common).autoconnect()

    var body: some View {
        ZStack {
            SeronaTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(alignment: .leading, spacing: 18) {
                topBar

                Text(selectedTab.title)
                    .font(.system(size: 34, weight: .bold))
                    .foregroundStyle(.black)
                    .padding(.horizontal, 28)

                if selectedTab == .bakWarna {
                    BakWarnaContentView(
                        baks: $baks,
                        onMulaiPindai: { bak in
                            if bak.isAktif {
                                bak.isTerhubung = true
                            } else {
                                setupTargetBak = bak
                            }
                        },
                        onSelesai: { bak in
                            if activeAlertBak?.id == bak.id {
                                dismissActiveAlert(openRepair: false)
                            }
                            queuedAlertBaks.removeAll { $0.id == bak.id }
                            bak.finishBak()
                        },
                        onPerbaikiLarutan: { bak in
                            repairTargetBak = bak
                        },
                        onTriggerWarningAlert: { bak in
                            enqueueQualityAlert(for: bak)
                        }
                    )
                } else {
                    ResepWarnaContentView(
                        reseps: reseps,
                        onSelectResep: { resep in
                            editingResep = resep
                        }
                    )
                }
            }

            // Centered Bak Setup Modal Overlay
            if let targetBak = setupTargetBak {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        setupTargetBak = nil
                    }

                BakSetupModalView(
                    bak: targetBak,
                    reseps: $reseps,
                    onClose: {
                        setupTargetBak = nil
                    },
                    onComplete: {
                        if !baks.contains(where: { $0.id == targetBak.id }) {
                            baks.append(targetBak)
                        }
                        setupTargetBak = nil
                    }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            // Centered Resep Modal Overlay (Create or Edit pre-filled Resep)
            if isAddingNewResep || editingResep != nil {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()
                    .onTapGesture {
                        isAddingNewResep = false
                        editingResep = nil
                    }

                ResepFormModalView(
                    existingResep: editingResep,
                    onClose: {
                        isAddingNewResep = false
                        editingResep = nil
                    },
                    onSave: { savedResep in
                        if let editing = editingResep,
                           let index = reseps.firstIndex(where: { $0.id == editing.id }) {
                            reseps[index] = savedResep
                        } else {
                            reseps.append(savedResep)
                        }
                        isAddingNewResep = false
                        editingResep = nil
                    }
                )
                .transition(.scale(scale: 0.96).combined(with: .opacity))
            }

            // Centered Quality Alert Overlay
            if let alertBak = activeAlertBak {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                QualityAlertModalView(
                    bak: alertBak,
                    onPerbaiki: {
                        dismissActiveAlert(openRepair: true)
                    },
                    onDismiss: {
                        dismissActiveAlert(openRepair: false)
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }

            // Centered Perbaiki Larutan 3-Step Modal Overlay
            if let repairBak = repairTargetBak {
                Color.black.opacity(0.28)
                    .ignoresSafeArea()

                PerbaikiLarutanModalView(
                    bak: repairBak,
                    onDismiss: {
                        repairTargetBak = nil
                        showNextQueuedAlertIfNeeded()
                    }
                )
                .transition(.scale(scale: 0.95).combined(with: .opacity))
            }
        }
        .animation(.easeInOut(duration: 0.18), value: setupTargetBak?.id)
        .animation(.easeInOut(duration: 0.18), value: isAddingNewResep)
        .animation(.easeInOut(duration: 0.18), value: editingResep?.id)
        .animation(.easeInOut(duration: 0.20), value: activeAlertBak?.id)
        .animation(.easeInOut(duration: 0.20), value: repairTargetBak?.id)
        .onAppear {
            checkInitialWarnings()
        }
        // 2. Receive timer ticks to fluctuate connected bak values
        .onReceive(liveSensorTimer) { _ in
            withAnimation(.easeInOut(duration: 0.35)) {
                for bak in baks where repairTargetBak?.id != bak.id {
                    let newlyTriggeredWarning = bak.simulateLiveDecrease()
                    if newlyTriggeredWarning && !bak.hasShownAutoAlert {
                        bak.hasShownAutoAlert = true
                        enqueueQualityAlert(for: bak)
                    }
                }
            }
        }
    }

    // MARK: - Top Bar

    private var topBar: some View {
        ZStack {
            HStack(spacing: 0) {
                ForEach(SeronaTab.allCases, id: \.self) { tab in
                    Button {
                        withAnimation(.easeInOut(duration: 0.18)) {
                            selectedTab = tab
                        }
                    } label: {
                        Text(tab.title)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(selectedTab == tab ? SeronaTheme.oliveGreenText : .black)
                            .frame(width: 210, height: 38)
                            .background(
                                Capsule()
                                    .fill(selectedTab == tab ? Color.black.opacity(0.08) : Color.clear)
                            )
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(4)
            .background(
                Capsule()
                    .fill(Color.white.opacity(0.55))
                    .overlay(
                        Capsule().stroke(Color.white.opacity(0.8), lineWidth: 1)
                    )
                    .shadow(color: .black.opacity(0.06), radius: 8, x: 0, y: 3)
            )

            HStack {
                Spacer()
                Button {
                    if selectedTab == .bakWarna {
                        let nextIndex = baks.count + 1
                        let newBak = DummyBakItem(nama: "Bak \(nextIndex)", isAktif: false, isTerhubung: false)
                        setupTargetBak = newBak
                    } else {
                        editingResep = nil
                        isAddingNewResep = true
                    }
                } label: {
                    Image(systemName: "plus")
                        .font(.title3.weight(.medium))
                        .foregroundStyle(.white)
                        .frame(width: 44, height: 44)
                        .background(SeronaTheme.oliveGreen, in: Circle())
                        .shadow(color: SeronaTheme.oliveGreen.opacity(0.25), radius: 6, x: 0, y: 3)
                }
                .buttonStyle(.plain)
                .accessibilityLabel(selectedTab == .bakWarna ? "Tambah Bak" : "Tambah Resep")
            }
        }
        .padding(.horizontal, 28)
        .padding(.top, 14)
    }

    // MARK: - Alert Queue Lifecycle

    private func checkInitialWarnings() {
        for bak in baks where bak.stage == .activeWarning && !bak.hasShownAutoAlert {
            bak.hasShownAutoAlert = true
            enqueueQualityAlert(for: bak)
        }
    }

    private func enqueueQualityAlert(for bak: DummyBakItem) {
        guard bak.isAktif, repairTargetBak?.id != bak.id else { return }
        if activeAlertBak?.id == bak.id { return }

        if activeAlertBak == nil, repairTargetBak == nil {
            activeAlertBak = bak
        } else if !queuedAlertBaks.contains(where: { $0.id == bak.id }) {
            queuedAlertBaks.append(bak)
        }
    }

    private func dismissActiveAlert(openRepair: Bool) {
        QualityAlarmPlayer.shared.stop()
        let current = activeAlertBak
        activeAlertBak = nil

        if openRepair, let current {
            repairTargetBak = current
        } else {
            showNextQueuedAlertIfNeeded()
        }
    }

    private func showNextQueuedAlertIfNeeded() {
        guard activeAlertBak == nil, repairTargetBak == nil, !queuedAlertBaks.isEmpty else { return }
        let next = queuedAlertBaks.removeFirst()
        if next.stage == .activeWarning {
            activeAlertBak = next
        } else {
            showNextQueuedAlertIfNeeded()
        }
    }
}
