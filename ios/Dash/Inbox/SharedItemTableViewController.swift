//
//  SharedItemTableViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/27.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import SafariServices

class SharedItemTableViewController: UITableViewController {
    static let bottomInsetForAutoNextPageLoading: CGFloat = 200

    static func pushMapsViewControllerForParkingSearchInCurrentScene(location: Location) {
        guard let windowScene = UIApplication.shared.foregroundWindowScene,
              let sceneDelegate = windowScene.delegate as? SceneDelegate,
              let inboxNavigationController = sceneDelegate.tabBarController.viewController(for: .inbox) as? UINavigationController,
              let sharedItemTableViewController = inboxNavigationController.viewControllers.first as? SharedItemTableViewController
        else { return }

        inboxNavigationController.popToRootViewController(animated: false)
        sharedItemTableViewController.pushMapsViewControllerForParkingSearch(location: location)
        sceneDelegate.tabBarController.selectedViewController = inboxNavigationController
    }

    var dataSource: SharedItemTableViewDataSource?

    var authentication: FirebaseAuthentication {
        return Firebase.shared.authentication
    }

    var isVisible: Bool {
        return isViewLoaded && view.window != nil
    }

    private var sharedItemDatabaseObservation: NSKeyValueObservation?

    override func viewDidLoad() {
        super.viewDidLoad()

        sharedItemDatabaseObservation = Firebase.shared.observe(\.sharedItemDatabase, options: .initial) { [weak self] (firbase, change) in
            self?.sharedItemDatabaseDidChange()
        }

        updateLeftBarButtonItems()
        navigationItem.rightBarButtonItem = editButtonItem
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        if authentication.vehicleID == nil {
            showSignInView()
        }
    }

    func sharedItemDatabaseDidChange() {
        updateDataSource()
        updateLeftBarButtonItems()
    }

    func updateDataSource() {
        if let database = Firebase.shared.sharedItemDatabase {
            let dataSource = SharedItemTableViewDataSource(database: database, tableView: tableView) { [unowned self] (tableView, indexPath, itemIdentifier) in
                guard let dataSource = self.dataSource else { return nil }

                let cell = tableView.dequeueReusableCell(withIdentifier: "SharedItemTableViewCell",for: indexPath) as! SharedItemTableViewCell
                cell.item = dataSource.item(for: indexPath)

                if cell.parkingSearchButton.actions(forTarget: self, forControlEvent: .touchUpInside) == nil {
                    cell.parkingSearchButton.addTarget(self, action: #selector(self.parkingSearchButtonTapped), for: .touchUpInside)
                }

                return cell
            }

            self.dataSource = dataSource
            tableView.dataSource = dataSource
        } else {
            tableView.dataSource = nil
            dataSource = nil

            if isVisible {
                showSignInView()
            }
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

    func showSignInView() {
        self.performSegue(withIdentifier: "showSignIn", sender: self)
    }

    override func tableView(_ tableView: UITableView, willDisplayHeaderView view: UIView, forSection section: Int) {
        let headerView = view as! UITableViewHeaderFooterView
        headerView.textLabel?.font = UIFont.preferredFont(forTextStyle: .subheadline)
    }

    override func tableView(_ tableView: UITableView, didSelectRowAt indexPath: IndexPath) {
        guard let dataSource = dataSource, !tableView.isEditing else { return }

        let item = dataSource.item(for: indexPath)
        item.markAsOpened(true)
        item.open(from: self)

        if let indexPathForSelectedRow = tableView.indexPathForSelectedRow {
            tableView.deselectRow(at: indexPathForSelectedRow, animated: true)
        }
    }

    override func scrollViewDidScroll(_ scrollView: UIScrollView) {
        guard let dataSource = dataSource else { return }

        let currentBottom = tableView.contentOffset.y + tableView.bounds.height
        let maxScrollableBottom = tableView.contentSize.height + tableView.adjustedContentInset.bottom
        let isInScrollAreaForAutoNextPageLoading = currentBottom >= maxScrollableBottom - Self.bottomInsetForAutoNextPageLoading

        if isInScrollAreaForAutoNextPageLoading, !wasInScrollAreaForAutoNextPageLoading {
            Task {
                guard await !dataSource.isLoadingNewPage else { return }
                await dataSource.incrementPage()
            }
        }

        wasInScrollAreaForAutoNextPageLoading = isInScrollAreaForAutoNextPageLoading
    }

    private var wasInScrollAreaForAutoNextPageLoading = false

    @objc func parkingSearchButtonTapped(button: UIButton) {
        var view: UIView = button

        while let superview = view.superview {
            if let cell = superview as? SharedItemTableViewCell {
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

private extension SharedItemTableViewController {
    func actionMenu(for location: Location) -> UIMenu {
        let locationActionsMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: String(localized: "Search Parkings"), image: UIImage(systemName: "parkingsign")) { [weak self] (action) in
                guard let self = self else { return }
                location.markAsOpened(true)
                self.pushMapsViewControllerForParkingSearch(location: location)
            }
        ])

        let otherAppActionsMenu = UIMenu(title: "", options: .displayInline, children: [
            UIAction(title: String(localized: "Google Maps"), image: UIImage(systemName: "g.circle.fill")) { (action) in
                location.markAsOpened(true)
                UIApplication.shared.open(location.googleMapsDirectionsURL)
            },
            UIAction(title: String(localized: "Yahoo! CarNavi"), image: UIImage(systemName: "y.circle.fill")) { (action) in
                location.markAsOpened(true)
                UIApplication.shared.open(location.yahooCarNaviURL)
            }
        ])

        let webActionsMenu = UIMenu(title: "", options: .displayInline, children: [
            {
                guard let websiteURL = location.websiteURL else { return nil }

                return UIAction(title: String(localized: "Open Website"), image: UIImage(systemName: "safari")) { [weak self] (action) in
                    guard let self = self else { return }
                    location.markAsOpened(true)
                    self.presentWebViewController(url: websiteURL)
                }
            }(),
            UIAction(title: String(localized: "Search Web"), image: UIImage(systemName: "magnifyingglass")) { [weak self] (action) in
                guard let self = self else { return }

                let query = [
                    location.name,
                    location.address.prefecture,
                    location.address.distinct,
                    location.address.locality,
                ].compactMap { $0 }.joined(separator: " ")

                var urlComponents = URLComponents(string: "https://google.com/search")!
                urlComponents.queryItems = [URLQueryItem(name: "q", value: query)]
                guard let url = urlComponents.url else { return }

                location.markAsOpened(true)
                self.presentWebViewController(url: url)
            }
        ].compactMap { $0 })

        return UIMenu(children: [
            locationActionsMenu,
            otherAppActionsMenu,
            webActionsMenu
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

    func actionMenu(for website: Website) -> UIMenu {
        return UIMenu(children: [
            UIAction(title: String(localized: "Open in Safari"), image: UIImage(systemName: "safari")) { (action) in
                website.markAsOpened(true)
                UIApplication.shared.open(website.url)
            }
        ])
    }
}
