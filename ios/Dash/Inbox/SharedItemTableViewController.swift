//
//  SharedItemTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import SafariServices

class SharedItemTableViewController: UITableViewController, SharedItemDatabaseDelegate {
    var database: SharedItemDatabase? {
        return Firebase.shared.sharedItemDatabase
    }

    lazy var dataSource = SharedItemTableViewDataSource(tableView: tableView) { [weak self] (tableView, indexPath, itemIdentifier) in
        guard let self = self else { return nil }
        let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItemTableViewCell",for: indexPath) as! SharedItemTableViewCell
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

    private var pendingUpdate: SharedItemDatabase.Update?

    override func viewDidLoad() {
        super.viewDidLoad()

        tableView.dataSource = dataSource

        sharedItemDatabaseObservation = Firebase.shared.observe(\.sharedItemDatabase, options: .initial) { [weak self] (firbase, change) in
            self?.sharedItemDatabaseDidChange()
        }

        updateDataSource()

        navigationItem.leftBarButtonItem = editButtonItem
        updateRightBarButtonItem()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if authentication.vehicleID == nil {
            showSignInView()
        }

        if let pendingUpdate = pendingUpdate {
            applyUpdate(pendingUpdate)
        }
    }

    @objc func sharedItemDatabaseDidChange() {
        updateDataSource()
        updateRightBarButtonItem()
    }

    @objc func updateDataSource() {
        if let database = database {
            database.delegate = self
            dataSource.setItems(database.items)
        } else {
            dataSource.setItems([])
            pendingUpdate = nil

            if isVisible {
                showSignInView()
            }
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        updateRightBarButtonItem()
    }

    func updateRightBarButtonItem() {
        if isEditing {
            navigationItem.rightBarButtonItem = UIBarButtonItem(barButtonSystemItem: .trash, target: self, action: #selector(trashBarButtonItemDidTap))
        } else {
            let pairingMenuItem = UIAction(title: "Pair with Dash Remote") { [unowned self] (action) in
                self.sharePairingURL()
            }

            let signOutMenuItem = UIAction(title: "Sign Out") { [unowned self] (action) in
                self.authentication.signOut()
            }

            let menu = UIMenu(title: authentication.email ?? "", children: [pairingMenuItem, signOutMenuItem])
            let barButtonItem = UIBarButtonItem(title: nil, image: UIImage(systemName: "person.circle"), primaryAction: nil, menu: menu)
            navigationItem.rightBarButtonItem = barButtonItem
        }
    }

    @objc func trashBarButtonItemDidTap() {
        assert(isEditing)

        guard let indexPaths = tableView.indexPathsForSelectedRows else { return }

        for indexPath in indexPaths {
            dataSource.item(for: indexPath).delete()
        }

        setEditing(false, animated: true)
    }

    func database(_ database: SharedItemDatabase, didUpdateItems update: SharedItemDatabase.Update) {
        if tableView.window == nil {
            pendingUpdate = update
        } else {
            applyUpdate(update)
        }
    }

    func applyUpdate(_ update: SharedItemDatabase.Update) {
        dataSource.setItems(update.items, changes: update.changes, animated: !dataSource.isEmpty)
        pendingUpdate = nil
    }

    func showSignInView() {
        self.performSegue(withIdentifier: "showSignIn", sender: self)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard !tableView.isEditing else { return }

        let item = dataSource.item(for: indexPath)
        item.open()

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {

        let actionProvider: UIContextMenuActionProvider = { [weak self] (suggestedActions) in
            guard let self = self else { return UIMenu() }

            switch self.item(for: indexPath) {
            case let location as Location:
                return self.actionMenu(for: location)
            case let musicItem as MusicItem:
                return self.actionMenu(for: musicItem)
            case let website as Website:
                return self.actionMenu(for: website)
            default:
                return UIMenu()
            }
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
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

private extension SharedItemTableViewController {
    func actionMenu(for location: Location) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: "Search Nearby Parkings", image: UIImage(systemName: "parkingsign")) { [weak self] (action) in
                guard let self = self else { return }

                location.markAsOpened()

                let mapsViewController = MapsViewController()
                mapsViewController.showsRecentSharedLocations = false
                mapsViewController.parkingSearchQuittingButton.isHidden = true

                self.navigationController?.pushViewController(mapsViewController, animated: true)

                mapsViewController.startSearchingParkings(destination: location.mapItem)
            },
            UIAction(title: "Get Directions in Google Maps", image: UIImage(systemName: "g.circle.fill")) { (action) in
                location.markAsOpened()
                UIApplication.shared.open(location.googleMapsDirectionsURL)
            }
        ])
    }

    func actionMenu(for musicItem: MusicItem) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: "Show in Apple Music", image: UIImage(systemName: "music.note")) { (action) in
                musicItem.markAsOpened()
                UIApplication.shared.open(musicItem.url)
            }
        ])
    }

    func actionMenu(for website: Website) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: "Open in In-App Browser", image: UIImage(systemName: "eye")) { [weak self] (action) in
                guard let self = self else { return }

                website.markAsOpened()

                let webViewController = WebViewController()
                webViewController.navigationItem.title = website.title
                webViewController.loadPage(url: website.url)

                let navigationController = UINavigationController(rootViewController: webViewController)
                navigationController.isToolbarHidden = false
                self.present(navigationController, animated: true)
            }
        ])
    }
}
