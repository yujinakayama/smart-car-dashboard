//
//  SharedItemTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseAuth

class SharedItemTableViewController: UITableViewController, SharedItemDatabaseDelegate {
    var database: SharedItemDatabase? {
        return Firebase.shared.sharedItemDatabase
    }

    lazy var dataSource = SharedItemTableViewDataSource(tableView: tableView) { [weak self] (tableView, indexPath, itemIdentifier) in
        guard let self = self else { return nil }
        let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItemTableViewCell") as! SharedItemTableViewCell
        cell.item = self.item(for: indexPath)
        return cell
    }

    var authentication: FirebaseAuthentication {
        return Firebase.shared.authentication
    }

    var isVisible: Bool {
        return isViewLoaded && view.window != nil
    }

    private var sharedItemDatabaseObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = dataSource

        sharedItemDatabaseObservation = Firebase.shared.observe(\.sharedItemDatabase, options: .initial) { [weak self] (firbase, change) in
            self?.sharedItemDatabaseDidChange()
        }

        updateDataSource()
        setUpNavigationItem()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if authentication.vehicleID == nil {
            showSignInView()
        }
    }

    @objc func sharedItemDatabaseDidChange() {
        updateDataSource()
        setUpNavigationItem()
    }

    @objc func updateDataSource() {
        if let database = database {
            database.delegate = self
            dataSource.setItems(database.items)
        } else {
            dataSource.setItems([])

            if isVisible {
                showSignInView()
            }
        }
    }

    func setUpNavigationItem() {
        navigationItem.leftBarButtonItem = editButtonItem

        let pairingMenuItem = UIAction(title: "Pair with Dash Remote") { [unowned self] (action) in
            self.sharePairingURL()
        }

        let signOutMenuItem = UIAction(title: "Sign out") { (action) in
            try? Auth.auth().signOut()
        }

        navigationItem.rightBarButtonItem?.menu = UIMenu(title: authentication.email ?? "", children: [pairingMenuItem, signOutMenuItem])
    }

    func database(_ database: SharedItemDatabase, didUpdateItems items: [SharedItemProtocol], withChanges changes: [SharedItemDatabase.Change]) {
        dataSource.setItems(items, changes: changes, animated: !dataSource.isEmpty)
    }

    func showSignInView() {
        self.performSegue(withIdentifier: "showSignIn", sender: self)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = dataSource.item(for: indexPath)
        item.open()

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }

    func item(for indexPath: IndexPath) -> SharedItemProtocol {
        return dataSource.item(for: indexPath)
    }

    func sharePairingURL() {
        guard let vehicleID = authentication.vehicleID else { return }

        let pairingURLItem = PairingURLItem(vehicleID: vehicleID)
        let activityViewController = UIActivityViewController(activityItems: [pairingURLItem], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityViewController, animated: true)
    }
}
