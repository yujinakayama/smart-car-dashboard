//
//  ProximityViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreLocation
import HomeKit

class ProximityViewController: UITableViewController {
    enum Section: Int {
        case targetIBeacon = 0
        case automation
        case currentlyDetectedBeacon
    }

    @IBOutlet weak var uuidTableViewCell: UITableViewCell!
    @IBOutlet weak var majorTableViewCell: UITableViewCell!

    @IBOutlet weak var autoLockDoorsWhenLeaveTableViewCell: UITableViewCell!

    @IBOutlet weak var proximityTableViewCell: UITableViewCell!
    @IBOutlet weak var accuracyTableViewCell: UITableViewCell!
    @IBOutlet weak var rssiTableViewCell: UITableViewCell!

    var detector: VehicleProximityDetector! {
        let appDelegate = UIApplication.shared.delegate as! AppDelegate
        return appDelegate.doorLockManager.vehicleProximityDetector
    }

    var lastBeaconRangingTime: Date?

    override func viewDidLoad() {
        super.viewDidLoad()

        let switchView = UISwitch()
        switchView.isOn = Defaults.shared.autoLockDoorsWhenLeave
        switchView.addTarget(self, action: #selector(autoLockDoorsWhenLeaveSwitchValueChanged), for: .valueChanged)
        autoLockDoorsWhenLeaveTableViewCell.accessoryView = switchView

        NotificationCenter.default.addObserver(self, selector: #selector(vehicleProximityDetectorDidRangeBeacon), name: .VehicleProximityDetectorDidRangeBeacon, object: nil)
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        detector.startRangingBeacon()

        updateContentConfiguration(
            of: uuidTableViewCell,
            text: "UUID",
            secondaryText: VehicleProximityDetector.beaconUUID.uuidString
        )

        updateContentConfiguration(
            of: majorTableViewCell,
            text: "Major",
            secondaryText: String(detector.beaconMajorValue)
        )

        updateAutoLockCell()

        updateCurrentlyDetectedBeaconSection(nil)
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        detector.stopRangingBeacon()
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let selectedCell = tableView.cellForRow(at: indexPath) else { return }

        switch selectedCell {
        case uuidTableViewCell:
            UIPasteboard.general.string = VehicleProximityDetector.beaconUUID.uuidString
        case majorTableViewCell:
            UIPasteboard.general.string = String(detector.beaconMajorValue)
        default:
            break
        }

        tableView.deselectRow(at: indexPath, animated: true)

        postLocalNotification(body: "foobar")
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

    func updateAutoLockCell() {
        updateContentConfiguration(
            of: autoLockDoorsWhenLeaveTableViewCell,
            text: "Auto-lock doors when leave",
            secondaryText: Defaults.shared.lockMechanismAccessoryName
        )
    }

    @objc func autoLockDoorsWhenLeaveSwitchValueChanged(_ switchView: UISwitch) {
        Defaults.shared.autoLockDoorsWhenLeave = switchView.isOn

        if switchView.isOn {
            let pickerController = HomeAccessoryPickerController(serviceType: HMServiceTypeLockMechanism)
            pickerController.delegate = self
            pickerController.navigationItem.title = "Select Vehicle Door Lock"
            let navigationController = UINavigationController(rootViewController: pickerController)
            present(navigationController, animated: true)
        } else {
            Defaults.shared.lockMechanismServiceUUID = nil
            Defaults.shared.lockMechanismAccessoryName = nil
            updateAutoLockCell()
        }
    }

    @objc func vehicleProximityDetectorDidRangeBeacon(_ notification: Notification) {
        let beacon = notification.userInfo?[VehicleProximityDetector.UserInfoKey.beacon] as? CLBeacon
        lastBeaconRangingTime = Date()
        // Update section header
        tableView.reloadSections(.init(integer: Section.currentlyDetectedBeacon.rawValue), with: .none)
        updateCurrentlyDetectedBeaconSection(beacon)
    }

    func updateCurrentlyDetectedBeaconSection(_ beacon: CLBeacon?) {
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

extension ProximityViewController: HomeAccessoryPickerControllerDelegate {
    func homeAccessoryPickerController(_ pickerController: HomeAccessoryPickerController, didFinishPickingAccessory accessory: HMAccessory) {
        pickerController.dismiss(animated: true)

        guard let lockMechanismService = accessory.services.first(where: { $0.serviceType == HMServiceTypeLockMechanism }) else { return }

        Defaults.shared.lockMechanismServiceUUID = lockMechanismService.uniqueIdentifier
        Defaults.shared.lockMechanismAccessoryName = accessory.name
        updateAutoLockCell()
    }
}

fileprivate func updateContentConfiguration(of cell: UITableViewCell, text: String?, secondaryText: String?) {
    var content = cell.defaultContentConfiguration()
    content.text = text
    content.secondaryText = secondaryText
    content.secondaryTextProperties.color = .secondaryLabel
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
