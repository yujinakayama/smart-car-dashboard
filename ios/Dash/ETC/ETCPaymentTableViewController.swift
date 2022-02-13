//
//  MasterViewController.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/05/28.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

@MainActor
class ETCPaymentTableViewController: UITableViewController {
    var card: ETCCard? {
        didSet {
            navigationItem.title = card?.displayedName ?? String(localized: "All ETC Payments")
        }
    }

    var dataSource: ETCPaymentTableViewDataSource?

    var deviceManager: ETCDeviceManager {
        return Vehicle.default.etcDeviceManager
    }

    private var cardUUIDToRestore: UUID?

    lazy var deviceStatusBarItemManager = ETCDeviceStatusBarItemManager(deviceManager: deviceManager)

    override var splitViewController: ETCSplitViewController {
        return super.splitViewController as! ETCSplitViewController
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        deviceStatusBarItemManager.addBarItem(to: navigationItem)

        // To update relative dates in section headers when the current date changed
        NotificationCenter.default.addObserver(tableView!, selector: #selector(tableView.reloadData), name: UIApplication.significantTimeChangeNotification, object: nil)

        startUpdatingDataSource()
    }

    func startUpdatingDataSource() {
        keyValueObservation = deviceManager.observe(\.database, options: .initial) { [weak self] (deviceManager, change) in
            guard let self = self else { return }

            Task {
                await self.updateDataSource(database: deviceManager.database)
            }
        }
    }

    func updateDataSource(database: ETCDatabase?) async {
        guard let database = database else {
            tableView.dataSource = nil
            dataSource = nil
            return
        }

        if let cardUUIDToRestore = self.cardUUIDToRestore {
            do {
                card = try await database.findCard(uuid: cardUUIDToRestore)
            } catch {
                logger.error(error)
            }
        }

        do {
            dataSource = try ETCPaymentTableViewDataSource(
                database: database,
                card: card,
                tableView: tableView
            ) { [unowned self] (tableView, indexPath, itemIdentifier) in
                return self.tableView(tableView, cellForRowAt: indexPath)
            }

            tableView.dataSource = dataSource
        } catch {
            logger.error(error)
            tableView.dataSource = nil
            dataSource = nil
        }
    }

    private var keyValueObservation: NSKeyValueObservation?

    func restoreCard(for uuid: UUID) {
        cardUUIDToRestore = uuid
    }

    // MARK: - Segues

    override func shouldPerformSegue(withIdentifier identifier: String, sender: Any?) -> Bool {
        if identifier == "showDetail" {
            if let detailNavigationController = splitViewController.detailNavigationController {
                if let indexPath = tableView.indexPathForSelectedRow, let payment = dataSource?.payment(for: indexPath) {
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
            guard let payment = dataSource?.payment(for: indexPath) else { return }
            let navigationController = segue.destination as! UINavigationController
            splitViewController.detailNavigationController = navigationController
            showPayment(payment, in: navigationController.topViewController as! ETCPaymentDetailViewController)
        }
    }

    func showPayment(_ payment: ETCPayment, in detailViewController: ETCPaymentDetailViewController) {
        detailViewController.payment = payment

        if splitViewController.displayMode == .oneOverSecondary {
            UIView.animate(withDuration: 0.25, animations: { [unowned self] in
                self.splitViewController.preferredDisplayMode = .secondaryOnly
            }, completion: { (completed) in
                self.splitViewController.preferredDisplayMode = .automatic
            })
        }
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "ETCPaymentTableViewCell", for: indexPath) as! ETCPaymentTableViewCell
        cell.payment = dataSource?.payment(for: indexPath)
        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let dataSource = dataSource else { return }

        if pagination.shouldLoadNextPage() {
            Task {
                guard await !dataSource.isLoadingNewPage else { return }
                await dataSource.incrementPage()
            }
        }
    }

    private lazy var pagination = ScrollViewPagination(scrollView: tableView)
}

