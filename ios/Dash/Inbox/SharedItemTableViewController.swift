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
    let database = SharedItemDatabase.shared

    var dataSource: SharedItemTableViewDataSource!

    var authStateListener: AuthStateDidChangeListenerHandle?

    override func viewDidLoad() {
        super.viewDidLoad()

        database.delegate = self

        dataSource = makeDataSource()
        tableView.dataSource = dataSource

        navigationItem.leftBarButtonItem = editButtonItem

        startObservingAuthState()
    }

    deinit {
        database.endUpdating()
        endObservingAuthState()
    }

    func makeDataSource() -> SharedItemTableViewDataSource {
        return SharedItemTableViewDataSource(tableView: tableView) { (tableView, indexPath, itemIdentifier) in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItemTableViewCell") as! SharedItemTableViewCell
            cell.item = self.dataSource.item(for: indexPath)
            return cell
        }
    }

    func startObservingAuthState() {
        guard authStateListener == nil else { return }

        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            self.authStateDidChange()
        }
    }

    func endObservingAuthState() {
        guard let authStateListener = authStateListener else { return }

        Auth.auth().removeStateDidChangeListener(authStateListener)
        self.authStateListener = nil
    }

    func authStateDidChange() {
        let firebaseUser = Auth.auth().currentUser

        logger.info("Current Firebase user: \(firebaseUser?.email as String?)")

        if firebaseUser != nil {
            database.startUpdating()
        } else {
            database.endUpdating()
            dataSource.update(items: [])
            showSignInView()
        }
    }

    func database(_ database: SharedItemDatabase, didUpdateItems items: [SharedItemProtocol], withChanges changes: [SharedItemDatabase.Change]) {
        dataSource.update(items: items, changes: changes, animatingDifferences: !dataSource.isEmpty)
        updateBadge()
    }

    func updateBadge() {
        let unopenedCount = database.items.filter { !$0.hasBeenOpened }.count
        navigationController?.tabBarItem.badgeValue = (unopenedCount == 0) ? nil : "\(unopenedCount)"
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
}
