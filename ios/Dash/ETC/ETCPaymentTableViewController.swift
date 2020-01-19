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
    let device = ETCDevice()

    lazy var fetchedResultsController: NSFetchedResultsController<ETCPaymentManagedObject> = {
        let request: NSFetchRequest<ETCPaymentManagedObject> = ETCPaymentManagedObject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: device.dataStore.viewContext,
            sectionNameKeyPath: "sectionIdentifier",
            cacheName: nil
        )

        controller.delegate = self

        return controller
    }()

    var detailViewController: ETCPaymentDetailViewController?

    var detailNavigationController: UINavigationController? {
        return detailViewController?.navigationController
    }

    lazy var connectionStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        return view
    }()

    lazy var cardStatusImageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "creditcard.fill")
        view.contentMode = .scaleAspectFit
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        return view
    }()

    let sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        setupNotificationObservations()

        device.startPreparation()

        assignDetailViewControllerIfExists()

        navigationItem.rightBarButtonItems = [
            UIBarButtonItem(customView: connectionStatusImageView),
            UIBarButtonItem(customView: cardStatusImageView)
        ]

        updateConnectionStatusView()
        updateCardStatusView()
    }

    override func viewWillAppear(_ animated: Bool) {
        clearsSelectionOnViewWillAppear = splitViewController!.isCollapsed
        super.viewWillAppear(animated)
    }

    func setupNotificationObservations() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: .ETCDeviceDidFinishDataStorePreparation, object: device, queue: .main) { (notification) in
            try! self.fetchedResultsController.performFetch()
            self.tableView.reloadData()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidConnect, object: device, queue: .main) { (notification) in
            self.updateConnectionStatusView()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDisconnect, object: device, queue: .main) { (notification) in
            self.updateConnectionStatusView()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDetectCardInsertion, object: device, queue: .main) { (notification) in
            self.updateCardStatusView()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDetectCardEjection, object: device, queue: .main) { (notification) in
            self.updateCardStatusView()
        }
    }

    func assignDetailViewControllerIfExists() {
        guard let navigationController = splitViewController!.viewControllers.last as? UINavigationController else { return }
        detailViewController = navigationController.topViewController as? ETCPaymentDetailViewController
    }

    func updateConnectionStatusView() {
        if device.isConnected {
            connectionStatusImageView.image = UIImage(systemName: "bolt.fill")
            connectionStatusImageView.tintColor = nil
        } else {
            connectionStatusImageView.image = UIImage(systemName: "bolt.slash.fill")
            connectionStatusImageView.tintColor = UIColor.lightGray
        }
    }

    func updateCardStatusView() {
        if device.currentCard != nil {
            cardStatusImageView.tintColor = nil
        } else {
            cardStatusImageView.tintColor = UIColor.lightGray
        }
    }

    // MARK: - Segues

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            if detailNavigationController == nil {
                return true
            } else {
                if let indexPath = tableView.indexPathForSelectedRow {
                    let payment = fetchedResultsController.object(at: indexPath)
                    showPayment(payment)
                    showDetailViewController(detailNavigationController!, sender: self)
                }
                return false
            }
        } else {
            return true
        }
    }

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        if segue.identifier == "showDetail", let indexPath = tableView.indexPathForSelectedRow {
            let navigationController = segue.destination as! UINavigationController
            detailViewController = (navigationController.topViewController as! ETCPaymentDetailViewController)
            let payment = fetchedResultsController.object(at: indexPath)
            showPayment(payment)
        }
    }

    func showPayment(_ payment: ETCPaymentProtocol?) {
        detailViewController?.payment = payment

        if splitViewController!.displayMode == .primaryOverlay {
            UIView.animate(withDuration: 0.25, animations: { [unowned self] in
                self.splitViewController!.preferredDisplayMode = .primaryHidden
            }, completion: { (completed) in
                self.splitViewController!.preferredDisplayMode = .automatic
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
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ETCPaymentTableViewCell

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

