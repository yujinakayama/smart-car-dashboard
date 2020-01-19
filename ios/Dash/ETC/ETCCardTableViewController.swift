//
//  ETCCardTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreData

class ETCCardTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    let device = ETCDevice()

    lazy var deviceStatusBar = ETCDeviceStatusBar(device: device)

    lazy var fetchedResultsController: NSFetchedResultsController<ETCCardManagedObject> = {
        let request: NSFetchRequest<ETCCardManagedObject> = ETCCardManagedObject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: device.dataStore.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        controller.delegate = self

        return controller
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.tableFooterView = UIView()

        navigationItem.rightBarButtonItems = deviceStatusBar.items

        startObservingNotifications()

        device.startPreparation()
    }

    func startObservingNotifications() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: .ETCDeviceDidFinishDataStorePreparation, object: device, queue: .main) { (notification) in
            try! self.fetchedResultsController.performFetch()
            self.tableView.reloadData()
        }
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "show", let indexPath = tableView.indexPathForSelectedRow {
            let paymentTableViewController = segue.destination as! ETCPaymentTableViewController
            paymentTableViewController.device = device
            let card = fetchedResultsController.object(at: indexPath)
            paymentTableViewController.card = card
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ETCCardTableViewCell", for: indexPath) as! ETCCardTableViewCell
        let card = fetchedResultsController.object(at: indexPath)
        cell.card = card
        return cell
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        switch type {
        case .insert:
            tableView.insertSections(IndexSet(integer: sectionIndex), with: .left)
        case .delete:
            tableView.deleteSections(IndexSet(integer: sectionIndex), with: .fade)
        case .move:
            break
        case .update:
            break
        @unknown default:
            break
        }
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange anObject: Any, at indexPath: IndexPath?, for type: NSFetchedResultsChangeType, newIndexPath: IndexPath?) {
        switch type {
        case .insert:
            tableView.insertRows(at: [newIndexPath!], with: .left)
        case .delete:
            tableView.deleteRows(at: [indexPath!], with: .fade)
        case .update:
            tableView.reloadRows(at: [indexPath!], with: .none)
        case .move:
            tableView.moveRow(at: indexPath!, to: newIndexPath!)
        @unknown default:
            break
        }
    }

    func controllerDidChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.endUpdates()
    }
}
