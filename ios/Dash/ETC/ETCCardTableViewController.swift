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

    var isVisible: Bool {
        return isViewLoaded && view.window != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.contentInset.top += 12
        tableView.tableFooterView = UIView()

        setUpNavigationBar()

        startObservingNotifications()

        device.startPreparation()
    }

    func setUpNavigationBar() {
        navigationItem.leftBarButtonItem = editButtonItem
        navigationItem.rightBarButtonItems = deviceStatusBar.items
    }

    func startObservingNotifications() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: .ETCDeviceDidFinishDataStorePreparation, object: device, queue: .main) { (notification) in
            try! self.fetchedResultsController.performFetch()
            self.tableView.reloadData()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDetectCardInsertion, object: device, queue: .main) { (notification) in
            self.indicateCurrentCard()
            if self.isVisible {
                self.showPaymentsForCurrentCard()
            }
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDetectCardEjection, object: device, queue: .main) { (notification) in
            self.indicateCurrentCard()
        }
    }

    func indicateCurrentCard() {
        tableView.reloadSections(IndexSet(integer: 0), with: .none)
    }

    func showPaymentsForCurrentCard() {
        let currentCard = try! device.dataStore.viewContext.existingObject(with: device.currentCard!.objectID) as! ETCCardManagedObject
        let indexPath = fetchedResultsController.indexPath(forObject: currentCard)
        tableView.selectRow(at: indexPath, animated: true, scrollPosition: .none)
        performSegue(withIdentifier: "show", sender: self)
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
        cell.isCurrentCard = card.objectID == device.currentCard?.objectID
        return cell
    }

    // MARK: - UITableViewDelegate

    override func tableView(_ tableView: UITableView, editingStyleForRowAt indexPath: IndexPath) -> UITableViewCell.EditingStyle {
        return .none
    }

    // UITableViewCell.shouldIndentWhileEditing does not work with UITableView.Style.insetGrouped
    // but this does work.
    override func tableView(_ tableView: UITableView, shouldIndentWhileEditingRowAt indexPath: IndexPath) -> Bool {
        return false
    }

    override func tableView(_ tableView: UITableView, accessoryButtonTappedForRowWith indexPath: IndexPath) {
        let card = fetchedResultsController.object(at: indexPath)

        let alertController = UIAlertController(title: "Card Name", message: nil, preferredStyle: .alert)

        alertController.addTextField { (textField) in
            textField.text = card.name
        }

        alertController.addAction(UIAlertAction(title: "Cancel", style: .cancel))

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { (action) in
            card.name = alertController.textFields!.first!.text
            try! card.managedObjectContext?.save()
        }))

        present(alertController, animated: true)
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
