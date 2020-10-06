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
    let database = SharedItemDatabase()

    // We don't directly store SharedItemProtocol object in the data source
    // because doing so requires SharedItemProtocol to conform to Hashable and Equatable,
    // which force the protocol to depend on `Self`, and it makes impossible to create an array of SharedItemProtocol.
    var dataSource: SharedItemTableViewDataSource!

    var data = SharedItemTableViewData()

    var authStateListener: AuthStateDidChangeListenerHandle?

    let sectionHeaderDateFormatter: DateFormatter = {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "ja_JP")
        formatter.dateStyle = .full
        return formatter
    }()

    override func viewDidLoad() {
        super.viewDidLoad()

        database.delegate = self

        dataSource = makeDataSource()
        tableView.dataSource = dataSource

        navigationItem.leftBarButtonItem = editButtonItem
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        startObservingAuthState()
    }

    deinit {
        database.endUpdating()
        endObservingAuthState()
    }

    func makeDataSource() -> SharedItemTableViewDataSource {
        let dataSource = SharedItemTableViewDataSource(tableView: tableView) { (tableView, indexPath, itemIdentifier) in
            let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItemTableViewCell") as! SharedItemTableViewCell
            cell.item = self.data.item(for: itemIdentifier)
            return cell
        }

        dataSource.titleForHeaderInSection = { [unowned self] (tableView, index) in
            let section = self.data.sections[index]
            return self.sectionHeaderDateFormatter.string(from: section.date)
        }

        dataSource.commitForRowAt = { (editingStyle, indexPath) in
            let item = self.data.item(for: indexPath)
            item.delete()
        }

        return dataSource
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
            data = SharedItemTableViewData()
            tableView.reloadData()
            showSignInView()
        }
    }

    func database(_ database: SharedItemDatabase, didUpdateItems items: [SharedItemProtocol]) {
        DispatchQueue.global().async { [weak self] in
            guard let self = self else { return }
            self.updateData(items: items, animatingDifferences: !self.data.sections.isEmpty)
        }
    }

    func updateData(items: [SharedItemProtocol], animatingDifferences: Bool) {
        data = SharedItemTableViewData(items: items)
        let dataSourceSnapshot = self.makeDataSourceSnapshot(from: data)
        dataSource.apply(dataSourceSnapshot, animatingDifferences: animatingDifferences)
    }

    func makeDataSourceSnapshot(from data: SharedItemTableViewData) -> NSDiffableDataSourceSnapshot<Date, SharedItem.Identifier> {
        var snapshot = NSDiffableDataSourceSnapshot<Date, SharedItem.Identifier>()

        snapshot.appendSections(data.sections.map { $0.date })

        for section in data.sections {
            snapshot.appendItems(section.items.map { $0.identifier }, toSection: section.date)
        }

        return snapshot
    }

    func showSignInView() {
        self.performSegue(withIdentifier: "showSignIn", sender: self)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = data.item(for: indexPath)
        item.open()

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }
}
