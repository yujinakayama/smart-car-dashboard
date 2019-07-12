//
//  MasterViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import CoreData

class ETCPaymentTableViewController: UITableViewController, NSFetchedResultsControllerDelegate, ETCDeviceManagerDelegate, ETCDeviceClientDelegate {
    let persistentContainer = NSPersistentContainer(name: "Dash")
    var fetchedResultsController: NSFetchedResultsController<ETCPaymentManagedObject>?

    var detailNavigationController: UINavigationController!
    var detailViewController: ETCPaymentDetailViewController!

    lazy var connectionStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        return view
    }()

    var deviceManager: ETCDeviceManager?
    var deviceClient: ETCDeviceClient?

    override func viewDidLoad() {
        super.viewDidLoad()

        // TODO: Load asynchronously with NSPersistentStoreDescription.shouldAddStoreAsynchronously
        persistentContainer.loadPersistentStores { (persistentStoreDescription, error) in
            if let error = error {
                logger.severe(error)
                fatalError()
            }
        }
        persistentContainer.viewContext.automaticallyMergesChangesFromParent = true

        let fetchRequest: NSFetchRequest<ETCPaymentManagedObject> = ETCPaymentManagedObject.fetchRequest()
        fetchRequest.sortDescriptors = [NSSortDescriptor(key: "date", ascending: false)]

        fetchedResultsController = NSFetchedResultsController(
            fetchRequest: fetchRequest,
            managedObjectContext: persistentContainer.viewContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )
        fetchedResultsController?.delegate = self
        try! fetchedResultsController?.performFetch()

        detailNavigationController = (splitViewController!.viewControllers.last as! UINavigationController)
        detailViewController = (detailNavigationController.topViewController as! ETCPaymentDetailViewController)

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
        deviceClient.startPreparation()
    }

    func deviceManager(_ deviceManager: ETCDeviceManager, didDisconnectToDevice deviceClient: ETCDeviceClient) {
        self.deviceClient = nil
        updateConnectionStatusView()
    }

    func deviceClientDidFinishPreparation(_ deviceClient: ETCDeviceClient, error: Error?) {
        updateConnectionStatusView()
        try! deviceClient.send(ETCMessageFromClient.initialPaymentRecordRequest)
    }

    func deviceClient(_ deviceClient: ETCDeviceClient, didReceiveMessage message: ETCMessageFromDeviceProtocol) {
        switch message {
        case is ETCMessageFromDevice.GateEntranceNotification:
            UserNotificationCenter.shared.requestDelivery(TollgateEntranceNotification())
        case is ETCMessageFromDevice.GateExitNotification:
            UserNotificationCenter.shared.requestDelivery(TollgateExitNotification())
        case let paymentNotification as ETCMessageFromDevice.PaymentNotification:
            if let amount = paymentNotification.amount {
                UserNotificationCenter.shared.requestDelivery(PaymentNotification(amount: amount))
            }
            try! deviceClient.send(ETCMessageFromClient.initialPaymentRecordRequest)
        case let paymentRecordResponse as ETCMessageFromDevice.PaymentRecordResponse:
            if let payment = paymentRecordResponse.payment {
                persistentContainer.performBackgroundTask { (context) in
                    let fetchRequest: NSFetchRequest<ETCPaymentManagedObject> = ETCPaymentManagedObject.fetchRequest()
                    fetchRequest.predicate = NSPredicate(format: "date == %@", payment.date as NSDate)
                    if try! context.count(for: fetchRequest) == 0 {
                        _ = ETCPaymentManagedObject.insertNewObject(from: payment, into: context)
                        try! context.save()
                        try! deviceClient.send(ETCMessageFromClient.nextPaymentRecordRequest)
                    }
                }
            }
        case is ETCMessageFromDevice.CardInsertionNotification:
            try! deviceClient.send(ETCMessageFromClient.initialPaymentRecordRequest)
        default:
            break
        }
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
        return fetchedResultsController?.sections?.count ?? 0
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return fetchedResultsController?.sections?[section].numberOfObjects ?? 0
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "Cell", for: indexPath) as! ETCPaymentTableViewCell

        let payment = fetchedResultsController?.object(at: indexPath)
        cell.payment = payment
        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let payment = fetchedResultsController?.object(at: indexPath)
        detailViewController!.payment = payment
        showDetailViewController(detailNavigationController, sender: self)

        if splitViewController!.displayMode == .primaryOverlay {
            UIView.animate(withDuration: 0.25, animations: { [unowned self] in
                self.splitViewController!.preferredDisplayMode = .primaryHidden
            }, completion: { (completed) in
                self.splitViewController!.preferredDisplayMode = .automatic
            })
        }
    }

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

