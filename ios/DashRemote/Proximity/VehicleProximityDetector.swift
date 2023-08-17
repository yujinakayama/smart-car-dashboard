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
    static let VehicleProximityDetectorDidEnterRegion = Notification.Name("VehicleProximityDetectorDidEnterRegion")
    static let VehicleProximityDetectorDidExitRegion = Notification.Name("VehicleProximityDetectorDidExitRegion")
    static let VehicleProximityDetectorDidRangeBeacon = Notification.Name("VehicleProximityDetectorDidRangeBeacon")
}

class VehicleProximityDetector: NSObject {
    static let beaconUUID = UUID(uuidString: "FB42EA58-A9EB-4431-B5BF-E98A81C4837F")!
    private static let beaconRegionIdentifier = "VehicleProximityDetector"

    let vehicleID: String

    lazy var beaconMajorValue: CLBeaconMajorValue = generate16bitDigestFromVehicleID()

    var isMonitoringForRegion: Bool {
        monitoringState != .idle || isAlreadyMonitoring
    }

    var isRangingBeacon: Bool {
        rangingState != .idle
    }

    private var monitoringState = RunningState.idle
    private var rangingState = RunningState.idle

    private lazy var locationManager = {
        let locationManager = CLLocationManager()
        locationManager.delegate = self
        return locationManager
    }()

    init(vehicleID: String) {
        self.vehicleID = vehicleID
    }

    func startMonitoringForRegion() {
        guard !isMonitoringForRegion else { return }

        switch locationManager.authorizationStatus {
        case .authorizedAlways:
            monitoringState = .running
            locationManager.startMonitoring(for: targetBeaconRegion)
        default:
            locationManager.requestAlwaysAuthorization()
        }
    }

    func stopMonitoringForRegion() {
        monitoringState = .idle
        locationManager.stopMonitoring(for: targetBeaconRegion)
    }

    private var isAlreadyMonitoring: Bool {
        locationManager.monitoredRegions.contains { region in
            guard let beaconRegion = region as? CLBeaconRegion else { return false}

            return beaconRegion.identifier == targetBeaconRegion.identifier
                && beaconRegion.uuid == targetBeaconRegion.uuid
                && beaconRegion.major == targetBeaconRegion.major
                && beaconRegion.minor == targetBeaconRegion.minor
        }
    }

    private lazy var targetBeaconRegion = CLBeaconRegion(
        beaconIdentityConstraint: beaconConstraint,
        identifier: Self.beaconRegionIdentifier
    )

    // Only for foreground
    func startRangingBeacon() {
        guard !isRangingBeacon else { return }

        switch locationManager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            rangingState = .running
            locationManager.startRangingBeacons(satisfying: beaconConstraint)
        default:
            locationManager.requestAlwaysAuthorization()
        }
    }

    func stopRangingBeacon() {
        rangingState = .idle
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
        switch manager.authorizationStatus {
        case .authorizedAlways, .authorizedWhenInUse:
            if monitoringState == .requested {
                monitoringState = .running
                locationManager.startMonitoring(for: targetBeaconRegion)
            }

            if rangingState == .requested {
                rangingState = .running
                locationManager.startRangingBeacons(satisfying: beaconConstraint)
            }
        default:
            break
        }
    }

    func locationManager(_ manager: CLLocationManager, didEnterRegion region: CLRegion) {
        print(#function)
        NotificationCenter.default.post(name: .VehicleProximityDetectorDidEnterRegion, object: self)
    }

    func locationManager(_ manager: CLLocationManager, didExitRegion region: CLRegion) {
        print(#function)
        NotificationCenter.default.post(name: .VehicleProximityDetectorDidExitRegion, object: self)
    }

    func locationManager(_ manager: CLLocationManager, monitoringDidFailFor region: CLRegion?, withError error: Error) {
        print(#function, error.localizedDescription)
    }

    func locationManager(_ manager: CLLocationManager, didRange beacons: [CLBeacon], satisfying beaconConstraint: CLBeaconIdentityConstraint) {
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
    enum RunningState {
        case idle
        case requested
        case running
    }
}

extension VehicleProximityDetector {
    struct UserInfoKey {
        static let beacon = "beacon"
    }
}
