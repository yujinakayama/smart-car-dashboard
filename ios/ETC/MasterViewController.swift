//
//  MasterViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

class MasterViewController: UITableViewController, ETCDeviceManagerDelegate, ETCDeviceDelegate {
    var detailViewController: DetailViewController? = nil

    var deviceManager: ETCDeviceManager?
    var device: ETCDevice?
    var observations: [NSKeyValueObservation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        if let split = splitViewController {
            let controllers = split.viewControllers
            detailViewController = (controllers[controllers.count-1] as! UINavigationController).topViewController as? DetailViewController
        }

        deviceManager = ETCDeviceManager(delegate: self)
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    // MARK: - ETCDeviceManagerDelegate

    func deviceManager(_ deviceManager: ETCDeviceManager, didConnectToDevice device: ETCDevice) {
        self.device = device
        device.delegate = self
        startObservingDeviceAttributes(device.attributes)
        device.startPreparation()
    }

    func deviceDidFinishPreparation(_ device: ETCDevice, error: Error?) {
        print(#function)
        try? device.send(ETCDevice.SendableMessage.initialUsageRecordRequest)
    }

    func startObservingDeviceAttributes(_ attributes: ETCDeviceAttributes) {
        let observation = attributes.observe(\.usages, options: .new) { [unowned self] (attributes, change) in
            self.tableView.reloadData()
        }
        observations.append(observation)
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail" {
            if let indexPath = tableView.indexPathForSelectedRow {
                let usage = device!.attributes.usages[indexPath.row]
                let controller = (segue.destination as! UINavigationController).topViewController as! DetailViewController
                controller.detailItem = usage
                controller.navigationItem.leftBarButtonItem = splitViewController?.displayModeButtonItem
                controller.navigationItem.leftItemsSupplementBackButton = true
            }
        }
    }

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return device?.attributes.usages.count ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath)

        let usage = device!.attributes.usages[indexPath.row]
        cell.textLabel!.text = usage.date?.description
        return cell
    }
}

