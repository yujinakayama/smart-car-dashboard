//
//  DoorLockManager.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import HomeKit
import UserNotifications

class DoorLockManager {
    static let shared = DoorLockManager()

    var vehicleProximityDetector: VehicleProximityDetector?

    private let homeManager = HMHomeManager()

    init() {
        updateVehicleProximityDetector()

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(updateVehicleProximityDetector),
            name: .PairedVehicleDidChangeDefaultVehicleID,
            object: nil
        )

        NotificationCenter.default.addObserver(
            self,
            selector: #selector(vehicleProximityDetectorDidExitRegion),
            name: .VehicleProximityDetectorDidExitRegion,
            object: nil
        )
    }

    @objc func updateVehicleProximityDetector() {
        vehicleProximityDetector?.stopMonitoringForRegion()

        if let vehicleID = PairedVehicle.defaultVehicleID {
            let detector = VehicleProximityDetector(vehicleID: vehicleID)
            detector.startMonitoringForRegion()
            vehicleProximityDetector = detector
        } else {
            vehicleProximityDetector = nil
        }
    }

    @objc func vehicleProximityDetectorDidExitRegion() {
        if Defaults.shared.autoLockDoorsWhenLeave, let serviceUUID = Defaults.shared.lockMechanismServiceUUID {
            secureLockMechanism(serviceID: serviceUUID)
        }
    }

    private func secureLockMechanism(serviceID: UUID) {
        guard let lockMechanismService = allLockMechanismServices.first(where: { $0.uniqueIdentifier == serviceID }),
              let targetLockStateCharacteristic = lockMechanismService.characteristics.first(where: { $0.characteristicType == HMCharacteristicTypeTargetLockMechanismState })
        else {
            postLocalNotification(body: "ドアロックのHomeKitアクセサリが見つかりません。")
            return
        }

        Task {
            do {
                try await targetLockStateCharacteristic.writeValue(HMCharacteristicValueLockMechanismState.secured.rawValue)
                postLocalNotification(body: "ドアを自動ロックしました。")
            } catch {
                postLocalNotification(body: error.localizedDescription)
            }
        }
    }

    private var allLockMechanismServices: [HMService] {
        guard homeManager.authorizationStatus.contains(.authorized) else { return [] }

        return homeManager.homes.flatMap { home in
            home.servicesWithTypes([HMServiceTypeLockMechanism]) ?? []
        }
    }

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
            print(#function, error as Any)
        }
    }
}
