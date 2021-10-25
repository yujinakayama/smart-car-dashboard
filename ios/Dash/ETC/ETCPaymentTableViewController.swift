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
    var device: ETCDevice {
        return Vehicle.default.etcDevice
    }

    var card: ETCCardManagedObject? {
        didSet {
            navigationItem.title = card?.displayedName ?? String(localized: "All ETC Payments")
        }
    }

    private var cardUUIDToRestore: UUID?

    lazy var deviceStatusBarItemManager = ETCDeviceStatusBarItemManager(device: device)

    var managedObjectContextObservation: NSKeyValueObservation?
    var fetchedResultsController: NSFetchedResultsController<ETCPaymentManagedObject>?

    override var splitViewController: ETCSplitViewController {
        return super.splitViewController as! ETCSplitViewController
    }

    let sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.dateStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        deviceStatusBarItemManager.addBarItem(to: navigationItem)

        startFetchingPayments()
    }

    func restoreCard(for uuid: UUID) {
        cardUUIDToRestore = uuid
    }

    func startFetchingPayments() {
        managedObjectContextObservation = device.dataStore.observe(\.viewContext, options: .initial) { [weak self] (dataStore, change) in
            guard let managedObjectContext = dataStore.viewContext else { return }
            self?.fetchPayments(managedObjectContext: managedObjectContext)
        }
    }

    func fetchPayments(managedObjectContext: NSManagedObjectContext) {
        if let cardUUIDToRestore = cardUUIDToRestore {
            card = try! device.dataStore.findCard(uuid: cardUUIDToRestore, in: managedObjectContext)
        }

        fetchedResultsController = makeFetchedResultsController(managedObjectContext: managedObjectContext)
        try! fetchedResultsController!.performFetch()
        tableView.reloadData()
    }

    func makeFetchedResultsController(managedObjectContext: NSManagedObjectContext) -> NSFetchedResultsController<ETCPaymentManagedObject> {
        let request: NSFetchRequest<ETCPaymentManagedObject> = ETCPaymentManagedObject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        if let card = card {
            request.predicate = NSPredicate(format: "card == %@", card)
        }

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: "sectionIdentifier",
            cacheName: nil
        )

        controller.delegate = self

        return controller
    }

    // MARK: - Segues

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            if let detailNavigationController = splitViewController.detailNavigationController {
                if let indexPath = tableView.indexPathForSelectedRow, let payment = fetchedResultsController?.object(at: indexPath) {
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
            guard let payment = fetchedResultsController?.object(at: indexPath) else { return }
            let navigationController = segue.destination as! UINavigationController
            splitViewController.detailNavigationController = navigationController
            showPayment(payment, in: navigationController.topViewController as! ETCPaymentDetailViewController)
        }
    }

    func showPayment(_ payment: ETCPaymentProtocol, in detailViewController: ETCPaymentDetailViewController) {
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
        return fetchedResultsController?.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController?.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        guard let payment = fetchedResultsController?.sections?[section].objects?.first as? ETCPaymentManagedObject else { return nil }
        return sectionHeaderDateFormatter.string(from: payment.date)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ETCPaymentTableViewCell", for: indexPath) as! ETCPaymentTableViewCell
        cell.payment = fetchedResultsController?.object(at: indexPath)
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

