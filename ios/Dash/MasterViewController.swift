//
//  MasterViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import Differ

class MasterViewController: UITableViewController, ETCDeviceManagerDelegate, ETCDeviceClientDelegate {
    var detailNavigationController: UINavigationController!
    var detailViewController: DetailViewController!

    lazy var connectionStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        return view
    }()

    var deviceManager: ETCDeviceManager?
    var deviceClient: ETCDeviceClient?
    var observations: [NSKeyValueObservation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        detailNavigationController = (splitViewController!.viewControllers.last as! UINavigationController)
        detailViewController = (detailNavigationController.topViewController as! DetailViewController)

        navigationItem.rightBarButtonItem = UIBarButtonItem(customView: connectionStatusImageView)
        updateConnectionStatusView()

        deviceManager = ETCDeviceManager(delegate: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    // MARK: - ETCDeviceManagerDelegate

    func deviceManager(_ deviceManager: ETCDeviceManager, didUpdateAvailability available: Bool) {
        if available {
            deviceManager.startDiscovering()
        }
    }

    func deviceManager(_ deviceManager: ETCDeviceManager, didConnectToDevice deviceClient: ETCDeviceClient) {
        self.deviceClient = deviceClient
        deviceClient.delegate = self
        startObservingDeviceAttributes(deviceClient.deviceAttributes)
        deviceClient.startPreparation()
    }

    func deviceManager(_ deviceManager: ETCDeviceManager, didDisconnectToDevice deviceClient: ETCDeviceClient) {
        self.deviceClient = nil
        updateConnectionStatusView()
        tableView.reloadData() // TODO: Persist usage history in Core Data
    }

    func deviceClientDidFinishPreparation(_ device: ETCDeviceClient, error: Error?) {
        updateConnectionStatusView()
        try! device.send(ETCMessageFromClient.initialUsageRecordRequest)
    }

    func deviceClient(_ deviceClient: ETCDeviceClient, didReceiveMessage message: ETCMessageFromDeviceProtocol) {
        switch message {
        case is ETCMessageFromDevice.GateEntranceNotification:
            UserNotificationManager.shared.deliverNotification(title: "Entered ETC gate")
        case is ETCMessageFromDevice.GateExitNotification:
            UserNotificationManager.shared.deliverNotification(title: "Exited ETC gate")
        case let paymentNotification as ETCMessageFromDevice.PaymentNotification:
            if let fee = paymentNotification.fee {
                UserNotificationManager.shared.deliverNotification(title: "ETC Payment: ¥\(fee)")
            }
            try! deviceClient.send(ETCMessageFromClient.initialUsageRecordRequest)
        default:
            break
        }
    }

    func startObservingDeviceAttributes(_ attributes: ETCDeviceAttributes) {
        let observation = attributes.observe(\.usages, options: [.old, .new]) { [unowned self] (attributes, change) in
            self.tableView.animateRowChangesWithoutMoves(
                oldData: change.oldValue!,
                newData: change.newValue!,
                deletionAnimation: .fade,
                insertionAnimation: .left
            )
        }
        observations.append(observation)
    }

    func updateConnectionStatusView() {
        if deviceClient?.isAvailable == true {
            connectionStatusImageView.image = UIImage(named: "bolt")
            connectionStatusImageView.tintColor = UIColor(hue: 263 / 360, saturation: 0.8, brightness: 1, alpha: 1)
        } else {
            connectionStatusImageView.image = UIImage(named: "bolt-slash")
            connectionStatusImageView.tintColor = UIColor.lightGray
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return deviceClient?.deviceAttributes.usages.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ETCUsageTableViewCell

        let usage = deviceClient!.deviceAttributes.usages[indexPath.row]
        cell.usage = usage
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let usage = deviceClient!.deviceAttributes.usages[indexPath.row]
        detailViewController!.usage = usage
        showDetailViewController(detailNavigationController, sender: self)

        if splitViewController!.displayMode == .primaryOverlay {
            UIView.animate(withDuration: 0.25, animations: { [unowned self] in
                self.splitViewController!.preferredDisplayMode = .primaryHidden
            }, completion: { (completed) in
                self.splitViewController!.preferredDisplayMode = .automatic
            })
        }
    }
}

