//
//  SharedItemTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseAuth
import FirebaseFirestore

class SharedItemTableViewController: UITableViewController {
    var authStateListener: AuthStateDidChangeListenerHandle?

    var querySnapshotListener: ListenerRegistration?

    var items: [SharedItemProtocol] = []

    lazy var firestoreQuery: Query = Firestore.firestore().collection("items").order(by: "creationTime", descending: true)

    override func viewDidLoad() {
        super.viewDidLoad()

        authStateDidChange()

        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            guard let self = self else { return }
            self.authStateDidChange()
        }
    }

    deinit {
        if let authStateListener = authStateListener {
            Auth.auth().removeStateDidChangeListener(authStateListener)
            self.authStateListener = nil
        }

        endLoadingItems()
    }

    func authStateDidChange() {
        let firebaseUser = Auth.auth().currentUser

        logger.info("Current Firebase user: \(firebaseUser?.email as String?)")

        if firebaseUser != nil {
            self.startLoadingItems()
        } else {
            self.showSignInView()
        }
    }

    func startLoadingItems() {
        guard querySnapshotListener == nil else { return }

        querySnapshotListener = firestoreQuery.addSnapshotListener { [weak self] (snapshot, error) in
            guard let self = self else { return }

            if let error = error {
                logger.error(error)
                return
            }

            guard let snapshot = snapshot else { return }

            let initialLoad = self.items.isEmpty

            self.setItems(from: snapshot)

            if initialLoad {
                self.tableView.reloadData()
            } else {
                self.itemCollectionDidChange(changes: snapshot.documentChanges)
            }
        }
    }

    func endLoadingItems() {
        guard let querySnapshotListener = querySnapshotListener else { return }

        querySnapshotListener.remove()
        self.querySnapshotListener = nil
    }

    func setItems(from snapshot: QuerySnapshot) {
        items = snapshot.documents.map({ (document) in
            do {
                return try SharedItem.makeItem(dictionary: document.data())
            } catch {
                logger.error(error)
                // Fill broken items since skipping them causes index misalignments in itemCollectionDidChange()
                return BrokenItem()
            }
        })
    }

    func showSignInView() {
        self.performSegue(withIdentifier: "showSignIn", sender: self)
    }

    // MARK: - UITableViewDataSource

    override func numberOfSections(in tableView: UITableView) -> Int {
        return 1
    }

    override func tableView(_ tableView: UITableView, numberOfRowsInSection section: Int) -> Int {
        return items.count
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItem", for: indexPath)

        let item = items[indexPath.row]

        switch item {
        case let location as Location:
            cell.textLabel?.text = location.name
            cell.detailTextLabel?.text = location.url.absoluteString
        case let webpage as Webpage:
            cell.textLabel?.text = webpage.title
            cell.detailTextLabel?.text = webpage.url.absoluteString
        default:
            cell.textLabel?.text = "Unknown"
            cell.detailTextLabel?.text = nil
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        let item = items[indexPath.row]
        item.open()

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }

    func itemCollectionDidChange(changes: [DocumentChange]) {
        tableView.beginUpdates()

        for change in changes {
            itemDidChange(change: change)
        }

        tableView.endUpdates()
    }

    func itemDidChange(change: DocumentChange) {
        let oldIndexPath = IndexPath(row: Int(change.oldIndex), section: 0)
        let newIndexPath = IndexPath(row: Int(change.newIndex), section: 0)

        switch change.type {
        case .added:
            tableView.insertRows(at: [newIndexPath], with: .left)
        case .removed:
            tableView.deleteRows(at: [oldIndexPath], with: .fade)
        case .modified:
            if oldIndexPath == newIndexPath {
                tableView.reloadRows(at: [oldIndexPath], with: .none)
            } else {
                tableView.moveRow(at: oldIndexPath, to: newIndexPath)
            }
        }
    }
}
