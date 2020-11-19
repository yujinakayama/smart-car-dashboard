//
//  MasterViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreData

class ETCPaymentTableViewController: UITableViewController, NSFetchedResultsControllerDelegate {
    var device: ETCDevice!

    var card: ETCCardManagedObject?

    lazy var deviceStatusBarItemManager = ETCDeviceStatusBarItemManager(device: device)

    lazy var fetchedResultsController: NSFetchedResultsController<ETCPaymentManagedObject> = {
        let request: NSFetchRequest<ETCPaymentManagedObject> = ETCPaymentManagedObject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        if let card = card {
            request.predicate = NSPredicate(format: "card == %@", card)
        }

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: device.dataStore.viewContext,
            sectionNameKeyPath: "sectionIdentifier",
            cacheName: nil
        )

        controller.delegate = self

        return controller
    }()

    override var splitViewController: ETCSplitViewController {
        return super.splitViewController as! ETCSplitViewController
    }

    let sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        try! fetchedResultsController.performFetch()

        setUpNavigationBar()

        startObservingNotifications()
    }

    func setUpNavigationBar() {
        navigationItem.title = card?.displayedName ?? "All Payments"
        deviceStatusBarItemManager.addBarItem(to: navigationItem)
    }

    func startObservingNotifications() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: .ETCDeviceDidFinishDataStorePreparation, object: device, queue: .main) { (notification) in
            try! self.fetchedResultsController.performFetch()
            self.tableView.reloadData()
        }
    }

    // MARK: - Segues

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            if let detailNavigationController = splitViewController.detailNavigationController {
                if let indexPath = tableView.indexPathForSelectedRow {
                    let payment = fetchedResultsController.object(at: indexPath)
                    showPayment(payment, in: detailNavigationController.topViewController as! ETCPaymentDetailViewController)
                    showDetailViewController(detailNavigationController, sender: self)
                }
                return false
            } else {
                return true
            }
        } else {
            return true
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail", let indexPath = tableView.indexPathForSelectedRow {
            let navigationController = segue.destination as! UINavigationController
            splitViewController.detailNavigationController = navigationController
            let payment = fetchedResultsController.object(at: indexPath)
            showPayment(payment, in: navigationController.topViewController as! ETCPaymentDetailViewController)
        }
    }

    func showPayment(_ payment: ETCPaymentProtocol?, in detailViewController: ETCPaymentDetailViewController) {
        detailViewController.payment = payment

        if splitViewController.displayMode == .oneOverSecondary {
            UIView.animate(withDuration: 0.25, animations: { [unowned self] in
                self.splitViewController.preferredDisplayMode = .secondaryOnly
            }, completion: { (completed) in
                self.splitViewController.preferredDisplayMode = .automatic
            })
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionInfo = fetchedResultsController.sections?[section]
        let payment = sectionInfo?.objects?.first as? ETCPaymentManagedObject
        return sectionHeaderDateFormatter.string(from: payment!.date)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ETCPaymentTableViewCell", for: indexPath) as! ETCPaymentTableViewCell

        let payment = fetchedResultsController.object(at: indexPath)
        cell.payment = payment
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
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

