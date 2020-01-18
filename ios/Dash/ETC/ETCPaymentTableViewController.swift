//
//  MasterViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreData

class ETCPaymentTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, ETCDeviceManagerDelegate, ETCDeviceConnectionDelegate {
    let paymentDatabase = ETCPaymentDatabase(name: "Dash")

    let cardUUIDNamespace = UUID(uuidString: "AE12B12B-2DD8-4FAB-9AD3-67FB3A15E12C")!

    var fetchedResultsController: NSFetchedResultsController<ETCPaymentManagedObject>?

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

    var deviceManager: ETCDeviceManager?
    var deviceConnection: ETCDeviceConnection?

    var lastPaymentNotificationTime: Date?

    let sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        paymentDatabase.loadPersistantStores { [unowned self] (persistentStoreDescription, error) in
            logger.debug(persistentStoreDescription)

            if let error = error {
                logger.severe(error)
                fatalError()
            }

            self.setupFetchedResultsController()
            self.setupDeviceManager()
        }

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

    func setupFetchedResultsController() {
        let fetchRequest = paymentDatabase.makeFetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: paymentDatabase.persistentContainer.viewContext,
            sectionNameKeyPath: "sectionIdentifier",
            cacheName: nil
        )

        fetchedResultsController!.delegate = self

        try! fetchedResultsController!.performFetch()

        tableView.reloadData()
    }

    func setupDeviceManager() {
        deviceManager = ETCDeviceManager(delegate: self)
        deviceManager!.startDiscovering()
    }

    func assignDetailViewControllerIfExists() {
        guard let navigationController = splitViewController!.viewControllers.last as? UINavigationController else { return }
        detailViewController = navigationController.topViewController as? ETCPaymentDetailViewController
    }

    // MARK: - ETCDeviceManagerDelegate

    func deviceManager(_ deviceManager: ETCDeviceManager, didConnectToDevice deviceConnection: ETCDeviceConnection) {
        self.deviceConnection = deviceConnection
        deviceConnection.delegate = self
        deviceConnection.startPreparation()
    }

    func deviceManager(_ deviceManager: ETCDeviceManager, didDisconnectToDevice deviceConnection: ETCDeviceConnection) {
        self.deviceConnection = nil
        updateConnectionStatusView()
        updateCardStatusView()
    }

    // MARK: - ETCDeviceClientDelegate

    func deviceConnectionDidFinishPreparation(_ deviceConnection: ETCDeviceConnection, error: Error?) {
        updateConnectionStatusView()
    }

    func deviceConnectionDidDetectCardInsertion(_ deviceConnection: ETCDeviceConnection) {
        try! deviceConnection.send(ETCMessageFromClient.uniqueCardDataRequest)
        updateCardStatusView()
    }

    func deviceConnectionDidDetectCardEjection(_ deviceConnection: ETCDeviceConnection) {
        paymentDatabase.currentCard = nil
        updateCardStatusView()
    }

    // TODO: Extract to another class
    func deviceConnection(_ deviceConnection: ETCDeviceConnection, didReceiveMessage message: ETCMessageFromDeviceProtocol) {
        switch message {
        case is ETCMessageFromDevice.GateEntranceNotification, is ETCMessageFromDevice.GateExitNotification:
            UserNotificationCenter.shared.requestDelivery(TollgatePassingThroughNotification())
        case is ETCMessageFromDevice.PaymentNotification:
            lastPaymentNotificationTime = Date()
            try! deviceConnection.send(ETCMessageFromClient.initialPaymentRecordRequest)
        case let uniqueCardDataResponse as ETCMessageFromDevice.UniqueCardDataResponse:
            let cardUUID = UUID(version: .v5, namespace: cardUUIDNamespace, name: Data(uniqueCardDataResponse.payloadBytes))
            paymentDatabase.performBackgroundTask { [unowned self] (context) in
                let card = try! self.paymentDatabase.findOrInsertCard(uuid: cardUUID, in: context)
                if card != nil {
                    try! context.save()
                    self.paymentDatabase.currentCard = card
                    try! deviceConnection.send(ETCMessageFromClient.initialPaymentRecordRequest)
                }
            }
            try! deviceConnection.send(ETCMessageFromClient.initialPaymentRecordRequest)
        case let paymentRecordResponse as ETCMessageFromDevice.PaymentRecordResponse:
            if let payment = paymentRecordResponse.payment {
                if justReceivedPaymentNotification {
                    lastPaymentNotificationTime = nil
                    UserNotificationCenter.shared.requestDelivery(PaymentNotification(payment: payment))
                }

                paymentDatabase.performBackgroundTask { [unowned self] (context) in
                    let managedObject = try! self.paymentDatabase.insert(payment: payment, unlessExistsIn: context)
                    if managedObject != nil {
                        try! context.save()
                        try! deviceConnection.send(ETCMessageFromClient.nextPaymentRecordRequest)
                    }
                }
            }
        default:
            break
        }
    }

    var justReceivedPaymentNotification: Bool {
        if let lastPaymentNotificationTime = lastPaymentNotificationTime {
            return Date().timeIntervalSince(lastPaymentNotificationTime) < 3
        } else {
            return false
        }
    }

    func updateConnectionStatusView() {
        if deviceConnection?.isAvailable == true {
            connectionStatusImageView.image = UIImage(systemName: "bolt.fill")
            connectionStatusImageView.tintColor = nil
        } else {
            connectionStatusImageView.image = UIImage(systemName: "bolt.slash.fill")
            connectionStatusImageView.tintColor = UIColor.lightGray
        }
    }

    func updateCardStatusView() {
        if deviceConnection?.isCardInserted == true {
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
                    let payment = fetchedResultsController?.object(at: indexPath)
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
            let payment = fetchedResultsController?.object(at: indexPath)
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

    // MARK: - Table View

    override func numberOfSections(in tableView: UITableView) -> Int {
        return fetchedResultsController?.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController?.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        let sectionInfo = fetchedResultsController?.sections?[section]
        let payment = sectionInfo?.objects?.first as? ETCPaymentManagedObject
        return sectionHeaderDateFormatter.string(from: payment!.date)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ETCPaymentTableViewCell

        let payment = fetchedResultsController?.object(at: indexPath)
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
            tableView.reloadRows(at: [indexPath!], with: .fade)
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

