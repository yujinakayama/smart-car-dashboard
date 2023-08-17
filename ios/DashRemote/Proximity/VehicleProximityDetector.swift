//
//  VehicleProximityDetector.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import CoreLocation
import CommonCrypto

extension Notification.Name {
    static let VehicleProximityDetectorDidRangeBeacon = Notification.Name("VehicleProximityDetectorDidRangeBeacon")
}

class VehicleProximityDetector: NSObject {
    static let beaconUUID = UUID(uuidString: "FB42EA58-A9EB-4431-B5BF-E98A81C4837F")!

    let vehicleID: String

    lazy var beaconMajorValue: CLBeaconMajorValue = generate16bitDigestFromVehicleID()

    var isRanging = false

    private lazy var locationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        return locationManager
    }()

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    deinit {
        stopRangingBeacon()
    }

    // Only for foreground
    func startRangingBeacon() {
        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isRanging = true
            locationManager.startRangingBeacons(satisfying: beaconConstraint)
        default:
            locationManager.requestAlwaysAuthorization()
        }
    }

    func stopRangingBeacon() {
        isRanging = false
        locationManager.stopRangingBeacons(satisfying: beaconConstraint)
    }

    private lazy var beaconConstraint = CLBeaconIdentityConstraint(
        uuid: Self.beaconUUID,
        major: beaconMajorValue
    )

    private func generate16bitDigestFromVehicleID() -> UInt16 {
        let vehicleIDData = vehicleID.data(using: .utf8)!

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        _ = vehicleIDData.withUnsafeBytes { (dataPointer) in
            CC_SHA1(dataPointer.baseAddress, CC_LONG(vehicleIDData.count), &digest)
        }

        // Use only first 2 bytes (16-bit)
        return (UInt16(digest[0]) << 8) + UInt16(digest[1])
    }
}

extension VehicleProximityDetector: CLLocationManagerDelegate {
    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        guard isRanging else { return }

        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            isRanging = true
            locationManager.startRangingBeacons(satisfying: beaconConstraint)
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
        print(#function, beacons)

        let beacon = beacons.first

        NotificationCenter.default.post(name: .VehicleProximityDetectorDidRangeBeacon, object: self, userInfo: [
            UserInfoKey.beacon: beacon as Any
        ])
    }

    func locationManager(_ manager: CLLocationManager, didFailRangingFor beaconConstraint: CLBeaconIdentityConstraint, error: Error) {
        print(#function, error.localizedDescription)
    }
}

extension VehicleProximityDetector {
    struct UserInfoKey {
        static let beacon = "beacon"
    }
}
