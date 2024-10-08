//
//  ProximityViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation

class ProximityViewController: UITableViewController {
    enum Section: Int {
        case targetIBeacon = 0
        case automation
        case currentlyDetectedBeacon
    }

    @IBOutlet weak var proximityUUIDTableViewCell: UITableViewCell!
    @IBOutlet weak var majorTableViewCell: UITableViewCell!
    @IBOutlet weak var minorTableViewCell: UITableViewCell!

    @IBOutlet weak var autoLockDoorsWhenLeaveTableViewCell: UITableViewCell!

    @IBOutlet weak var proximityTableViewCell: UITableViewCell!
    @IBOutlet weak var accuracyTableViewCell: UITableViewCell!
    @IBOutlet weak var rssiTableViewCell: UITableViewCell!

    let autoLockDoorsWhenLeaveSwitch = UISwitch()

    var doorLockManager: DoorLockManager {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.doorLockManager
    }

    var proximityDetector: VehicleProximityDetector? {
        return doorLockManager.vehicleProximityDetector
    }

    var lastBeaconRangingTime: Date?

    override func viewDidLoad() {
        super.viewDidLoad()

        autoLockDoorsWhenLeaveSwitch.addTarget(self, action: #selector(autoLockDoorsWhenLeaveSwitchValueChanged), for: .valueChanged)
        autoLockDoorsWhenLeaveTableViewCell.accessoryView = autoLockDoorsWhenLeaveSwitch

        NotificationCenter.default.addObserver(self, selector: #selector(vehicleProximityDetectorDidRangeBeacon), name: .VehicleProximityDetectorDidRangeBeacon, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        proximityDetector?.startRangingBeacon()

        updateContentConfiguration(
            of: proximityUUIDTableViewCell,
            text: "Proximity UUID",
            secondaryText: VehicleProximityDetector.beaconProximityUUID.uuidString
        )

        updateContentConfiguration(
            of: majorTableViewCell,
            text: "Major",
            secondaryText: proximityDetector != nil ? String(proximityDetector!.beaconMajorValue) : "-"
        )

        updateContentConfiguration(
            of: minorTableViewCell,
            text: "Minor",
            secondaryText: "Any"
        )

        autoLockDoorsWhenLeaveSwitch.isOn = Defaults.shared.autoLockDoorsWhenLeave

        updateCurrentlyDetectedBeaconSection(for: nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        proximityDetector?.stopRangingBeacon()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }

        switch selectedCell {
        case proximityUUIDTableViewCell:
            UIPasteboard.general.string = VehicleProximityDetector.beaconProximityUUID.uuidString
        case majorTableViewCell:
            if let proximityDetector = proximityDetector {
                UIPasteboard.general.string = String(proximityDetector.beaconMajorValue)
            }
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(rawValue: section) {
        case .targetIBeacon:
            return "Target iBeacon"
        case .automation:
            return "Automation"
        case .currentlyDetectedBeacon:
            if let time = lastBeaconRangingTime {
                return "Currently Detected Beacon at \(timeFormatter.string(from: time))"
            } else {
                return "Currently Detected Beacon"
            }
        default:
            return nil
        }
    }

    @objc func autoLockDoorsWhenLeaveSwitchValueChanged() {
        Defaults.shared.autoLockDoorsWhenLeave = autoLockDoorsWhenLeaveSwitch.isOn
        doorLockManager.restartVehicleProximityDetectorIfNeeded()
    }

    @objc func vehicleProximityDetectorDidRangeBeacon(_ notification: Notification) {
        let beacon = notification.userInfo?[VehicleProximityDetector.UserInfoKey.beacon] as? CLBeacon
        lastBeaconRangingTime = Date()
        // Update section header
        tableView.reloadSections(.init(integer: Section.currentlyDetectedBeacon.rawValue), with: .none)
        updateCurrentlyDetectedBeaconSection(for: beacon)
    }

    func updateCurrentlyDetectedBeaconSection(for beacon: CLBeacon?) {
        updateContentConfiguration(
            of: proximityTableViewCell,
            text: "Proximity",
            secondaryText: beacon?.proximity.description ?? "-"
        )

        updateContentConfiguration(
            of: accuracyTableViewCell,
            text: "Accuracy",
            secondaryText: beacon?.accuracy.description ?? "-"
        )

        updateContentConfiguration(
            of: rssiTableViewCell,
            text: "Received Signal Strength Indicator",
            secondaryText: rssiText(for: beacon?.rssi)
        )
    }

    private func rssiText(for rssi: Int?) -> String {
        if let rssi = rssi {
            if rssi == 0 {
                return "Unknown"
            } else {
                return "\(rssi) dB"
            }
        } else {
            return "-"
        }
    }

    private lazy var timeFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.timeStyle = .medium
        return formatter
    }()
}

fileprivate func updateContentConfiguration(of cell: UITableViewCell, text: String?, secondaryText: String?) {
    var content = cell.defaultContentConfiguration()
    content.text = text
    content.secondaryText = secondaryText
    content.secondaryTextProperties.color = .secondaryLabel
    content.secondaryTextProperties.font = .preferredFont(forTextStyle: .subheadline)
    cell.contentConfiguration = content
}

fileprivate extension CLProximity {
    var description: String {
        switch self {
        case .unknown:
            return "Unknown"
        case .immediate:
            return "Immediate"
        case .near:
            return "Near"
        case .far:
            return "Far"
        default:
            return "Unknown (\(rawValue)"
        }
    }
}

fileprivate extension CLLocationAccuracy {
    var description: String {
        if self >= 0 {
            return String(format: "±%.1f m", self)
        } else {
            return "Unknown"
        }
    }
}
