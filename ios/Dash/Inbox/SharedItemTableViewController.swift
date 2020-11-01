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
    var database: SharedItemDatabase?

    var dataSource: SharedItemTableViewDataSource!

    var isVisible: Bool {
        return isViewLoaded && view.window != nil
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        dataSource = makeDataSource()
        tableView.dataSource = dataSource

        setUpNavigationItem()

        NotificationCenter.default.addObserver(self, selector: #selector(rebuildDatabase), name: .FirebaseAuthenticationDidChangeVehicleID, object: nil)
        rebuildDatabase()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if FirebaseAuthentication.vehicleID == nil {
            showSignInView()
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

        navigationItem.rightBarButtonItem?.menu = UIMenu(title: "", children: [pairingMenuItem, signOutMenuItem])
    }

    func makeDataSource() -> SharedItemTableViewDataSource {
        return SharedItemTableViewDataSource(tableView: tableView) { (tableView, indexPath, itemIdentifier) in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItemTableViewCell") as! SharedItemTableViewCell
            cell.item = self.dataSource.item(for: indexPath)
            return cell
        }
    }

    @objc func rebuildDatabase() {
        if let vehicleID = FirebaseAuthentication.vehicleID {
            let database = SharedItemDatabase(vehicleID: vehicleID)
            database.delegate = self
            database.startUpdating()
            self.database = database
        } else {
            database = nil
            dataSource.update(items: [])
            if isVisible {
                showSignInView()
            }
        }
    }

    func database(_ database: SharedItemDatabase, didUpdateItems items: [SharedItemProtocol], withChanges changes: [SharedItemDatabase.Change]) {
        dataSource.update(items: items, changes: changes, animatingDifferences: !dataSource.isEmpty)
        updateBadge()
    }

    func updateBadge() {
        if let database = database {
            let unopenedCount = database.items.filter { !$0.hasBeenOpened }.count
            navigationController?.tabBarItem.badgeValue = (unopenedCount == 0) ? nil : "\(unopenedCount)"
        } else {
            navigationController?.tabBarItem.badgeValue = nil
        }
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

    func sharePairingURL() {
        guard let vehicleID = FirebaseAuthentication.vehicleID else { return }

        let pairingURLItem = PairingURLItem(vehicleID: vehicleID)
        let activityViewController = UIActivityViewController(activityItems: [pairingURLItem], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityViewController, animated: true)
    }
}
