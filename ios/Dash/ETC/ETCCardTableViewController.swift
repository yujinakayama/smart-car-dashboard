//
//  ETCCardTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

@MainActor
class ETCCardTableViewController: UITableViewController {
    typealias Section = ETCCardTableViewDataSource.Section

    var dataSource: ETCCardTableViewDataSource?

    var deviceManager: ETCDeviceManager {
        return Vehicle.default.etcDeviceManager
    }

    lazy var deviceStatusBarItemManager = ETCDeviceStatusBarItemManager(deviceManager: deviceManager)

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.contentInset.top += 12
        tableView.tableFooterView = UIView()
        tableView.allowsSelectionDuringEditing = true

        setUpNavigationBar()

        startUpdatingDataSource()
    }

    func setUpNavigationBar() {
        navigationItem.leftBarButtonItem = editButtonItem
        deviceStatusBarItemManager.addBarItem(to: navigationItem)
    }

    func startUpdatingDataSource() {
        keyValueObservation = deviceManager.observe(\.database, options: .initial) { [weak self] (deviceManager, change) in
            guard let self = self else { return }
            Task {
                await self.updateDataSource(database: deviceManager.database)
            }
        }
    }

    private var keyValueObservation: NSKeyValueObservation?

    func updateDataSource(database: ETCDatabase?) {
        if let database = database {
            dataSource = ETCCardTableViewDataSource(database: database, tableView: tableView) { [unowned self] (tableView, indexPath, itemIdentifier) in
                return self.tableView(tableView, cellForRowAt: indexPath)
            }

            tableView.dataSource = self.dataSource
        } else {
            tableView.dataSource = nil
            dataSource = nil
        }
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
                    paymentTableViewController.card = dataSource?.card(for: indexPath)
                }
            }
        case "edit":
            if let indexPath = tableView.indexPathForSelectedRow, Section(indexPath) == .cards {
                let navigationController = segue.destination as! UINavigationController
                let cardEditViewController = navigationController.topViewController as! ETCCardEditViewController
                cardEditViewController.card = dataSource?.card(for: indexPath)
            }
        default:
            break
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        switch Section(indexPath)! {
        case .allPayments:
            return tableView.dequeueReusableCell(withIdentifier: "AllPaymentsCell", for: indexPath)
        case .cards:
            let cell = tableView.dequeueReusableCell(withIdentifier: "ETCCardTableViewCell", for: indexPath) as! ETCCardTableViewCell
            if let card = dataSource?.card(for: indexPath) {
                cell.card = card
                cell.isCurrentCard = card.uuid == deviceManager.currentCard?.uuid
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

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        if isEditing {
            performSegue(withIdentifier: "edit", sender: self)
        } else {
            performSegue(withIdentifier: "show", sender: self)
        }

        tableView.deselectRow(at: indexPath, animated: true)
    }
}
