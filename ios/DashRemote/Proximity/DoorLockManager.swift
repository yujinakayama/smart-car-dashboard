//
//  DoorLockManager.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import UserNotifications
import DashCloudKit

class DoorLockManager {
    var vehicleProximityDetector: VehicleProximityDetector?

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(pairedVehicleDidChangeDefaultVehicleID),
            name: .PairedVehicleDidChangeDefaultVehicleID,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vehicleProximityDetectorDidExitRegion),
            name: .VehicleProximityDetectorDidExitRegion,
            object: nil
        )

        startVehicleProximityDetectorIfNeeded()
    }

    func startVehicleProximityDetectorIfNeeded() {
        if let vehicleID = PairedVehicle.defaultVehicleID, Defaults.shared.autoLockDoorsWhenLeave {
            let detector = VehicleProximityDetector(vehicleID: vehicleID)
            detector.startMonitoringForRegionIfNeeded()
            vehicleProximityDetector = detector
        } else {
            vehicleProximityDetector = nil
        }
    }

    @objc func pairedVehicleDidChangeDefaultVehicleID() {
        // We don't want to unnecessarily invoke stopMonitoringForRegion() on app launch,
        // which may stop existing region monitoring.
        vehicleProximityDetector?.stopMonitoringForRegion()
        startVehicleProximityDetectorIfNeeded()
    }

    @objc func vehicleProximityDetectorDidExitRegion() {
        if let vehicleID = vehicleProximityDetector?.vehicleID {
            lockDoors(of: vehicleID)
        }
    }

    private func lockDoors(of vehicleID: String) {
        cloudClient.lockDoors(of: vehicleID) { [weak self] error in
            guard let self = self else { return }

            if let error = error {
                postLocalNotification(body: "ドアロックに失敗しました。 \(error.localizedDescription)")
            } else {
                postLocalNotification(body: "ドアを自動ロックしました。")
            }
        }
    }

    let cloudClient = DashCloudClient()

    private func postLocalNotification(body: String) {
        let content = UNMutableNotificationContent()
        content.body = body
        content.sound = .default

        let notificationRequest = UNNotificationRequest(
            identifier: UUID().uuidString,
            content: content,
            trigger: nil
        )

        UNUserNotificationCenter.current().add(notificationRequest) { error in
            logger.info(error)
        }
    }
}
