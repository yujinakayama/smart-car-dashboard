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

enum LocationActionType {
    case openDirectionsInAppleMaps
    case searchParkings
    case searchWeb
    case openWebsite
    case addToInbox
    case openDirectionsInGoogleMaps
    case openDirectionsInYahooCarNavi
}

class LocationActions {
    static let hostnameParser = try! TLDExtract(useFrozenData: true)
    
    let location: Location
    let viewController: UIViewController
    let searchParkingsHandler: (Location) -> Void

    init(location: Location, viewController: UIViewController, searchParkingsHandler: @escaping (Location) -> Void) {
        self.location = location
        self.viewController = viewController
        self.searchParkingsHandler = searchParkingsHandler
    }

    func action(for type: LocationActionType) -> PerformableAction? {
        let location = location
        let viewController = viewController
        let searchParkingsHandler = searchParkingsHandler

        switch type {
        case .openDirectionsInAppleMaps:
            return PerformableAction(title: String(localized: "Directions"), image: UIImage(systemName: "arrow.triangle.turn.up.right.circle.fill")) {
                openDirectionsInAppleMaps(location: location)
            }
        case .searchParkings:
            return PerformableAction(title: String(localized: "Search Parkings"), image: UIImage(systemName: "parkingsign")) {
                searchParkingsHandler(location)
            }
        case .searchWeb:
            guard case .full(let fullLocation) = location else { return nil }
            return PerformableAction(title: String(localized: "Search Web"), image: UIImage(systemName: "magnifyingglass")) {
                searchWeb(fullLocation: fullLocation, viewController: viewController)
            }
        case .openWebsite:
            guard case .full(let fullLocation) = location,
                  let websiteURL = fullLocation.websiteURL,
                  let rootDomain = Self.hostnameParser.parse(websiteURL)?.rootDomain
            else { return nil }
            // We don't display subdomain like Website.simplifiedHost
            // to avoid multi-line subtitle as context menu item is displayed in narrow width
            return PerformableAction(title: String(localized: "Open Website"), subtitle: rootDomain, image: UIImage(systemName: "safari")) {
                openWebsite(fullLocation: fullLocation, viewController: viewController)
            }
        case .addToInbox:
            guard case .full(let fullLocation) = location else { return nil }
            return PerformableAction(title: String(localized: "Add to Inbox"), image: UIImage(systemName: "tray.and.arrow.down.fill")) {
                addToInbox(fullLocation: fullLocation)
            }
        case .openDirectionsInGoogleMaps:
            return PerformableAction(title: String(localized: "Google Maps"), image: UIImage(systemName: "g.circle.fill")) {
                openDirectionsInGoogleMaps(location: location)
            }
        case .openDirectionsInYahooCarNavi:
            return PerformableAction(title: String(localized: "Yahoo! CarNavi"), image: UIImage(systemName: "y.circle.fill")) {
                openDirectionsInYahooCarNavi(location: location)
            }
        }
    }

    func makeMenu(for requestedActionTypes: [LocationActionType]) -> UIMenu {
        let locationActionTypes: [LocationActionType] = [.openDirectionsInAppleMaps, .searchParkings, .searchWeb, .openWebsite, .addToInbox]
        let locationActionsMenu = UIMenu(title: "", options: .displayInline, children: locationActionTypes.compactMap {
            guard requestedActionTypes.contains($0) else { return nil }
            return action(for: $0)?.uiAction
        })
        
        let otherAppActionTypes: [LocationActionType] = [.openDirectionsInGoogleMaps, .openDirectionsInYahooCarNavi]
        let otherAppActionsMenu = UIMenu(title: "", options: .displayInline, children: otherAppActionTypes.compactMap {
            guard requestedActionTypes.contains($0) else { return nil }
            return action(for: $0)?.uiAction

        })
        
        return UIMenu(children: [
            locationActionsMenu,
            otherAppActionsMenu
        ].filter { !$0.children.isEmpty })
    }
}

extension LocationActions {
    class PerformableAction {
        let title: String
        let subtitle: String?
        let image: UIImage?
        let handler: () -> Void
        
        init(title: String, subtitle: String? = nil, image: UIImage?, handler: @escaping () -> Void) {
            self.title = title
            self.subtitle = subtitle
            self.image = image
            self.handler = handler
        }
        
        func perform() {
            handler()
        }
        
        var uiAction: UIAction {
            UIAction(title: title, subtitle: subtitle, image: image) { _ in
                self.handler()
            }
        }
    }
}

fileprivate func openDirectionsInAppleMaps(location: Location) {
    location.markAsOpened(true)
    Task {
        await location.openDirectionsInMaps()
    }
}

fileprivate func searchWeb(fullLocation: FullLocation, viewController: UIViewController) {
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

fileprivate func openWebsite(fullLocation: FullLocation, viewController: UIViewController) {
    guard let websiteURL = fullLocation.websiteURL else { return }
    fullLocation.markAsOpened(true)
    WebViewController.present(url: websiteURL, from: viewController)
}

fileprivate func addToInbox(fullLocation: FullLocation) {
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

fileprivate func openDirectionsInGoogleMaps(location: Location) {
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

fileprivate func openDirectionsInYahooCarNavi(location: Location) {
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
