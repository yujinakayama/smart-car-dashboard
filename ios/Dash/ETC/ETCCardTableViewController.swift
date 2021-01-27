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
    enum Section: Int, CaseIterable {
        case allPayments = 0
        case cards

        init?(_ sectionIndex: Int) {
            if let section = Section(rawValue: sectionIndex) {
                self = section
            } else {
                return nil
            }
        }

        init?(_ indexPath: IndexPath) {
            if let section = Section(rawValue: indexPath.section) {
                self = section
            } else {
                return nil
            }
        }
    }

    var device: ETCDevice {
        return Vehicle.default.etcDevice
    }

    lazy var deviceStatusBarItemManager = ETCDeviceStatusBarItemManager(device: device)

    var fetchedResultsController: NSFetchedResultsController<ETCCardManagedObject>?

    var keyValueObservations: [NSKeyValueObservation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.contentInset.top += 12
        tableView.tableFooterView = UIView()

        setUpNavigationBar()

        startObservingCurrentCard()

        startFetchingCards()
    }

    func setUpNavigationBar() {
        navigationItem.leftBarButtonItem = editButtonItem
        deviceStatusBarItemManager.addBarItem(to: navigationItem)
    }

    func startObservingCurrentCard() {
        keyValueObservations.append(device.observe(\.currentCard) { [weak self] (currentCard, change) in
            DispatchQueue.main.async {
                self?.indicateCurrentCard()
            }
        })
    }

    func startFetchingCards() {
        if let managedObjectContext = device.dataStore.viewContext {
            fetchCards(managedObjectContext: managedObjectContext)
        } else {
            keyValueObservations.append(device.dataStore.observe(\.viewContext) { [weak self] (dataStore, change) in
                guard let managedObjectContext = dataStore.viewContext else { return }
                self?.fetchCards(managedObjectContext: managedObjectContext)
            })
        }
    }

    func fetchCards(managedObjectContext: NSManagedObjectContext) {
        fetchedResultsController = makeFetchedResultsController(managedObjectContext: managedObjectContext)
        try! fetchedResultsController!.performFetch()
        tableView.reloadData()
    }

    func makeFetchedResultsController(managedObjectContext: NSManagedObjectContext) -> NSFetchedResultsController<ETCCardManagedObject> {
        let request: NSFetchRequest<ETCCardManagedObject> = ETCCardManagedObject.fetchRequest()
        request.sortDescriptors = [NSSortDescriptor(key: "name", ascending: true)]

        let controller = NSFetchedResultsController(
            fetchRequest: request,
            managedObjectContext: managedObjectContext,
            sectionNameKeyPath: nil,
            cacheName: nil
        )

        controller.delegate = self

        return controller
    }

    func indicateCurrentCard() {
        tableView.reloadSections(IndexSet(integer: Section.cards.rawValue), with: .none)
    }

    // MARK: - Segues

    override func prepare(for segue: UIStoryboardSegue, sender: Any?) {
        switch segue.identifier {
        case "show":
            if let indexPath = tableView.indexPathForSelectedRow {
                let paymentTableViewController = segue.destination as! ETCPaymentTableViewController

                switch Section(indexPath)! {
                case .allPayments:
                    paymentTableViewController.card = nil
                case .cards:
                    paymentTableViewController.card = fetchedResultsController?.object(at: indexPath.adding(section: -1))
                }
            }
        case "edit":
            let navigationController = segue.destination as! UINavigationController
            let cardEditViewController = navigationController.topViewController as! ETCCardEditViewController
            cardEditViewController.card = (sender as! ETCCardManagedObject)
        default:
            break
        }
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return Section.allCases.count
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        switch Section(section)! {
        case .allPayments:
            return 1
        case .cards:
            return fetchedResultsController?.sections?.first?.numberOfObjects ?? 0
        }
    }

    override func tableView(_ tableView: UITableView, titleForHeaderInSection section: Int) -> String? {
        switch Section(section)! {
        case .allPayments:
            return nil
        case .cards:
            return "Cards"
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(indexPath)! {
        case .allPayments:
            return tableView.dequeueReusableCell(withIdentifier: "AllPaymentsCell", for: indexPath)
        case .cards:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ETCCardTableViewCell", for: indexPath) as! ETCCardTableViewCell
            if let card = fetchedResultsController?.object(at: indexPath.adding(section: -1)) {
                cell.card = card
                cell.isCurrentCard = card.objectID == device.currentCard?.objectID
            } else {
                cell.card = nil
                cell.isCurrentCard = false
            }
            return cell
        }
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
        guard Section(indexPath)! == .cards else { return }
        guard let card = fetchedResultsController?.object(at: indexPath.adding(section: -1)) else { return }
        performSegue(withIdentifier: "edit", sender: card)
    }

    // MARK: - NSFetchedResultsControllerDelegate

    func controllerWillChangeContent(_ controller: NSFetchedResultsController<NSFetchRequestResult>) {
        tableView.beginUpdates()
    }

    func controller(_ controller: NSFetchedResultsController<NSFetchRequestResult>, didChange sectionInfo: NSFetchedResultsSectionInfo, atSectionIndex sectionIndex: Int, for type: NSFetchedResultsChangeType) {
        let sectionIndex = sectionIndex + 1

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
        let indexPath = indexPath?.adding(section: 1)
        let newIndexPath = newIndexPath?.adding(section: 1)

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
