//
//  InboxItemTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import SafariServices

class InboxItemTableViewController: UITableViewController {
    static func pushMapsViewControllerForParkingSearchInCurrentScene(location: Location) {
        guard let windowScene = UIApplication.shared.foregroundWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate,
              let inboxNavigationController = sceneDelegate.tabBarController.viewController(for: .inbox) as? UINavigationController,
              let inboxItemTableViewController = inboxNavigationController.viewControllers.first as? InboxItemTableViewController
        else { return }

        inboxNavigationController.popToRootViewController(animated: false)
        inboxItemTableViewController.pushMapsViewControllerForParkingSearch(location: location)
        sceneDelegate.tabBarController.selectedViewController = inboxNavigationController
    }

    var dataSource: InboxItemTableViewDataSource?

    var authentication: FirebaseAuthentication {
        return Firebase.shared.authentication
    }

    private var inboxItemDatabaseObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        inboxItemDatabaseObservation = Firebase.shared.observe(\.inboxItemDatabase, options: .initial) { [weak self] (firbase, change) in
            self?.inboxItemDatabaseDidChange()
        }

        updateLeftBarButtonItems()
        navigationItem.rightBarButtonItem = editButtonItem
    }

    func inboxItemDatabaseDidChange() {
        updateDataSource()
        updateLeftBarButtonItems()
    }

    func updateDataSource() {
        if let database = Firebase.shared.inboxItemDatabase {
            dataSource = InboxItemTableViewDataSource(database: database, tableView: tableView) { [unowned self] (tableView, indexPath, itemIdentifier) in
                return self.tableView(tableView, cellForRowAt: indexPath)
            }

            tableView.dataSource = dataSource
        } else {
            tableView.dataSource = nil
            dataSource = nil
        }
    }

    override func setEditing(_ editing: Bool, animated: Bool) {
        super.setEditing(editing, animated: animated)
        updateLeftBarButtonItems()
    }

    func updateLeftBarButtonItems() {
        if isEditing {
            navigationItem.leftBarButtonItems = [
                deleteBarButtonItem,
                .fixedSpace(30),
                markBarButtonItem
            ]
        } else {
            navigationItem.leftBarButtonItems = [userBarButtonItem]
        }
    }

    private lazy var deleteBarButtonItem: UIBarButtonItem = {
        let barButtonItem = UIBarButtonItem(title: String(localized: "Delete"), style: .plain, target: self, action: #selector(trashBarButtonItemDidTap))
        barButtonItem.tintColor = .systemRed
        return barButtonItem
    }()

    private lazy var markBarButtonItem: UIBarButtonItem = {
        let markAsOpenedMenuItem = UIAction(title: String(localized: "Mark as Opened")) { [unowned self] (action) in
            self.markSelectedItemsAsOpened(true)
        }

        let markAsUnopenedMenuItem = UIAction(title: String(localized: "Mark as Unopened")) { [unowned self] (action) in
            self.markSelectedItemsAsOpened(false)
        }

        let markMenu = UIMenu(title: "", children: [markAsOpenedMenuItem, markAsUnopenedMenuItem])

        return UIBarButtonItem(title: String(localized: "Mark"), menu: markMenu)
    }()

    private lazy var userBarButtonItem: UIBarButtonItem = {
        let pairingMenuItem = UIAction(title: String(localized: "Pair with Dash Remote")) { [unowned self] (action) in
            self.sharePairingURL()
        }

        let signOutMenuItem = UIAction(title: String(localized: "Sign Out")) { [unowned self] (action) in
            self.authentication.signOut()
        }

        let menu = UIMenu(title: authentication.email ?? "", children: [pairingMenuItem, signOutMenuItem])

        return UIBarButtonItem(title: nil, image: UIImage(systemName: "person.circle"), primaryAction: nil, menu: menu)
    }()

    func markSelectedItemsAsOpened(_ value: Bool) {
        assert(isEditing)

        guard let dataSource = dataSource,
              let indexPaths = tableView.indexPathsForSelectedRows
        else { return }

        for indexPath in indexPaths {
            dataSource.item(for: indexPath).markAsOpened(value)
        }

        setEditing(false, animated: true)
    }

    @objc func trashBarButtonItemDidTap() {
        assert(isEditing)

        guard let dataSource = dataSource,
              let indexPaths = tableView.indexPathsForSelectedRows
        else { return }

        for indexPath in indexPaths {
            dataSource.item(for: indexPath).delete()
        }

        setEditing(false, animated: true)
    }

    override func tableView(_ tableView: UITableView, cellForRowAt indexPath: IndexPath) -> UITableViewCell {
        let cell = tableView.dequeueReusableCell(withIdentifier: "InboxItemTableViewCell",for: indexPath) as! InboxItemTableViewCell

        cell.item = dataSource?.item(for: indexPath)

        if cell.parkingSearchButton.actions(forTarget: self, forControlEvent: .touchUpInside) == nil {
            cell.parkingSearchButton.addTarget(
                self,
                action: #selector(self.parkingSearchButtonTapped),
                for: .touchUpInside
            )
        }

        return cell
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataSource = dataSource, !tableView.isEditing else { return }

        let item = dataSource.item(for: indexPath)
        item.markAsOpened(true)

        Task {
            await item.open(from: self)
        }

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
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

    @objc func parkingSearchButtonTapped(button: UIButton) {
        var view: UIView = button

        while let superview = view.superview {
            if let cell = superview as? InboxItemTableViewCell {
                if let location = cell.item as? Location {
                    location.markAsOpened(true)
                    pushMapsViewControllerForParkingSearch(location: location)
                }
                return
            }

            view = superview
        }
    }

    override func tableView(_ tableView: UITableView, contextMenuConfigurationForRowAt indexPath: IndexPath, point: CGPoint) -> UIContextMenuConfiguration? {
        guard let dataSource = dataSource else { return nil }

        let actionProvider: UIContextMenuActionProvider = { [weak self] (suggestedActions) in
            guard let self = self else { return UIMenu() }

            switch dataSource.item(for: indexPath) {
            case let location as Location:
                return self.actionMenu(for: location)
            case let musicItem as MusicItem:
                return self.actionMenu(for: musicItem)
            case let video as Video:
                return self.actionMenu(for: video)
            case let website as Website:
                return self.actionMenu(for: website)
            default:
                return UIMenu()
            }
        }

        return UIContextMenuConfiguration(identifier: nil, previewProvider: nil, actionProvider: actionProvider)
    }

    func pushMapsViewControllerForParkingSearch(location: Location) {
        let mapsViewController = MapsViewController()
        mapsViewController.showsRecentSharedLocations = false
        mapsViewController.parkingSearchQuittingButton.isHidden = true

        self.navigationController?.pushViewController(mapsViewController, animated: true)

        mapsViewController.startSearchingParkings(destination: location.mapItem)
    }

    func presentWebViewController(url: URL, title: String? = nil) {
        let webViewController = WebViewController()
        webViewController.navigationItem.title = title
        webViewController.loadPage(url: url)

        let navigationController = UINavigationController(rootViewController: webViewController)
        navigationController.isToolbarHidden = false
        navigationController.modalPresentationStyle = .formSheet
        navigationController.preferredContentSize = UIScreen.main.bounds.size
        self.present(navigationController, animated: true)
    }

    func sharePairingURL() {
        guard let vehicleID = authentication.vehicleID else { return }

        let pairingURLItem = PairingURLItem(vehicleID: vehicleID)
        let activityViewController = UIActivityViewController(activityItems: [pairingURLItem], applicationActivities: nil)
        activityViewController.popoverPresentationController?.barButtonItem = navigationItem.rightBarButtonItem
        present(activityViewController, animated: true)
    }
}

private extension InboxItemTableViewController {
    func actionMenu(for location: Location) -> UIMenu {
        let actions = LocationActions(location: location, viewController: self, searchParkingsHandler: { location in
            self.pushMapsViewControllerForParkingSearch(location: location)
        })

        return actions.makeMenu(for: [
            .searchParkings,
            .searchWeb,
            .openWebsite,
            .openDirectionsInGoogleMaps,
            .openDirectionsInYahooCarNavi
        ])
    }

    func actionMenu(for musicItem: MusicItem) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: String(localized: "Show in Apple Music"), image: UIImage(systemName: "music.note")) { (action) in
                musicItem.markAsOpened(true)
                UIApplication.shared.open(musicItem.url)
            }
        ])
    }

    func actionMenu(for video: Video) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: String(localized: "Open in In-App Browser"), image: UIImage(systemName: "safari")) { [weak self] (action) in
                guard let self = self else { return }
                video.markAsOpened(true)
                video.openInInAppBrowser(from: self)
            }
        ])
    }

    func actionMenu(for website: Website) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: String(localized: "Open in Safari"), image: UIImage(systemName: "safari")) { (action) in
                website.markAsOpened(true)
                UIApplication.shared.open(website.url)
            }
        ])
    }
}
