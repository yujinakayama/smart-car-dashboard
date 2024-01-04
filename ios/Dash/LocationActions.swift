//
//  LocationActions.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/24.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import MapKit
import TLDExtract
import DashCloudKit

protocol LocationAction {
    var menuPosition: LocationActions.MenuPosition { get }
    func perform()
    var title: String { get }
    var subtitle: String? { get }
    var image: UIImage { get }
}

extension LocationAction {
    var uiAction: UIAction {
        return UIAction(title: title, subtitle: subtitle, image: image) { _ in
            self.perform()
        }
    }
}

enum LocationActions {
    enum MenuGroup: CaseIterable {
        case main
        case otherApp
    }

    struct MenuPosition {
        var group: MenuGroup
        var order: UInt
    }
}

extension LocationActions {
    struct OpenDirectionsInAppleMaps: LocationAction {
        var menuPosition = MenuPosition(group: .main, order: 0)
        var location: Location

        func perform() {
            location.markAsOpened(true)
            Task {
                await location.openDirectionsInMaps()
            }
        }

        var title: String {
            String(localized: "Directions")
        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "arrow.triangle.turn.up.right.circle.fill")!
        }
    }

    struct SearchParkings: LocationAction {
        var menuPosition = MenuPosition(group: .main, order: 1)
        var location: Location
        var handler: () -> Void

        func perform() {
            location.markAsOpened(true)
            handler()
        }

        var title: String {
            String(localized: "Search Parkings")

        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "parkingsign")!
        }
    }

    struct ShowInMaps: LocationAction {
        var menuPosition = MenuPosition(group: .main, order: 2)
        var location: Location
        var handler: () -> Void

        func perform() {
            location.markAsOpened(true)
            handler()
        }

        var title: String {
            String(localized: "Show in Maps")

        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "mappin")!
        }
    }

    struct SearchWeb: LocationAction {
        var menuPosition = MenuPosition(group: .main, order: 3)
        var fullLocation: FullLocation
        var viewController: UIViewController

        func perform() {
            let query = [
                fullLocation.name,
                fullLocation.address.prefecture,
                fullLocation.address.distinct,
                fullLocation.address.locality,
            ].compactMap { $0 }.joined(separator: " ")

            var urlComponents = URLComponents(string: "https://google.com/search")!
            urlComponents.queryItems = [URLQueryItem(name: "q", value: query)]
            guard let url = urlComponents.url else { return }

            fullLocation.markAsOpened(true)
            WebViewController.present(url: url, from: viewController)
        }

        var title: String {
            String(localized: "Search Web")
        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "magnifyingglass")!
        }
    }

    struct OpenWebsite: LocationAction {
        static let hostnameParser = try! TLDExtract(useFrozenData: true)

        var menuPosition = MenuPosition(group: .main, order: 4)
        var fullLocation: FullLocation
        var viewController: UIViewController

        func perform() {
            guard let websiteURL = fullLocation.websiteURL else { return }
            fullLocation.markAsOpened(true)
            WebViewController.present(url: websiteURL, from: viewController)
        }

        var title: String {
            String(localized: "Open Website")
        }

        var subtitle: String? {
            guard let websiteURL = fullLocation.websiteURL else { return nil }
            // We don't display subdomain like Website.simplifiedHost
            // to avoid multi-line subtitle as context menu item is displayed in narrow width
            return Self.hostnameParser.parse(websiteURL)?.rootDomain
        }

        var image: UIImage {
            UIImage(systemName: "safari")!
        }
    }

    struct AddToInbox: LocationAction {
        var menuPosition = MenuPosition(group: .main, order: 5)
        var fullLocation: FullLocation

        func perform() {
            guard let vehicleID = Firebase.shared.authentication.vehicleID else { return }

            let mapItem = fullLocation.mapItem

            let encoder = Item.Encoder()
            encoder.add(mapItem)
            encoder.add(AppleMaps.shared.url(for: mapItem))
            let item = Item(encoder: encoder)

            let cloudClient = DashCloudClient()
            cloudClient.add(item, toInboxOf: vehicleID, notification: false) { error in
                if let error = error {
                    logger.error(error)
                }
            }
        }

        var title: String {
            String(localized: "Add to Inbox")
        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "tray.and.arrow.down.fill")!
        }
    }

    struct OpenDirectionsInGoogleMaps: LocationAction {
        var menuPosition = MenuPosition(group: .otherApp, order: 0)
        var location: Location

        func perform() {
            // https://developers.google.com/maps/documentation/urls/get-started#directions-action
            var components = URLComponents(string: "https://www.google.com/maps/dir/")!

            components.queryItems = [
                URLQueryItem(name: "api", value: "1"),
                URLQueryItem(name: "destination", value: "\(location.coordinate.latitude),\(location.coordinate.longitude)"),
                URLQueryItem(name: "travelmode", value: "driving")
            ]

            location.markAsOpened(true)
            UIApplication.shared.open(components.url!)
        }

        var title: String {
            String(localized: "Google Maps")
        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "g.circle.fill")!
        }
    }

    struct OpenDirectionsInYahooCarNavi: LocationAction {
        var menuPosition = MenuPosition(group: .otherApp, order: 1)
        var location: Location

        func perform() {
            // https://note.com/yahoo_carnavi/n/n1d6b819a816c
            var components = URLComponents(string: "yjcarnavi://navi/select")!

            components.queryItems = [
                URLQueryItem(name: "lat", value: "\(location.coordinate.latitude)"),
                URLQueryItem(name: "lon", value: "\(location.coordinate.longitude)"),
                URLQueryItem(name: "name", value: location.name)
            ]

            location.markAsOpened(true)
            UIApplication.shared.open(components.url!)
        }

        var title: String {
            String(localized: "Yahoo! CarNavi")
        }

        var subtitle: String? {
            nil
        }

        var image: UIImage {
            UIImage(systemName: "y.circle.fill")!
        }
    }
}

extension LocationActions {
    static func makeMenu(for actions: [LocationAction]) -> UIMenu {
        let groupedActions = Dictionary(grouping: actions) { $0.menuPosition.group }

        let subMenus: [UIMenu] = MenuGroup.allCases.compactMap { group in
            let actions = groupedActions[group] ?? []
            let uiActions = actions.sorted { $0.menuPosition.order < $1.menuPosition.order }.map { $0.uiAction }
            return UIMenu(title: "", options: .displayInline, children: uiActions)
        }

        return UIMenu(children: subMenus.filter { !$0.children.isEmpty })
    }
}
