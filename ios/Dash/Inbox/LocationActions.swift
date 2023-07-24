//
//  LocationActions.swift
//  Dash
//
//  Created by Yuji Nakayama on 2023/07/24.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import MapKit
import TLDExtract

enum LocationActionType {
    case searchParkings
    case searchWeb
    case openWebsite
    case openDirectionsInGoogleMaps
    case openDirectionsInYahooCarNavi
}

class LocationActions {
    typealias SearchParkingsHandler = (InboxLocation) -> Void

    static let hostnameParser = try! TLDExtract(useFrozenData: true)
    
    let location: InboxLocation
    let viewController: UIViewController
    let searchParkingsHandler: SearchParkingsHandler?

    init(location: InboxLocation, viewController: UIViewController, searchParkingsHandler: SearchParkingsHandler? = nil) {
        self.location = location
        self.viewController = viewController
        self.searchParkingsHandler = searchParkingsHandler
    }

    func searchParkings() {
        searchParkingsHandler?(location)
    }
    
    func searchWeb() {
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
        WebViewController.present(url: url, from: viewController)
    }

    func openWebsite() {
        guard let websiteURL = location.websiteURL else { return }
        location.markAsOpened(true)
        WebViewController.present(url: websiteURL, from: viewController)
    }
    
    func openDirectionsInGoogleMaps() {
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
    
    func openDirectionsInYahooCarNavi() {
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
    
    func makeMenu(for actionTypes: [LocationActionType]) -> UIMenu {
        let locationActionsMenu = UIMenu(title: "", options: .displayInline, children: [
            {
                guard actionTypes.contains(.searchParkings) else { return nil }
                return UIAction(title: String(localized: "Search Parkings"), image: UIImage(systemName: "parkingsign")) { (action) in
                    self.searchParkings()
                }
            }(),
            {
                guard actionTypes.contains(.searchWeb) else { return nil }
                return UIAction(title: String(localized: "Search Web"), image: UIImage(systemName: "magnifyingglass")) { (action) in
                    self.searchWeb()
                }
            }(),
            {
                guard actionTypes.contains(.openWebsite), let websiteURL = location.websiteURL else { return nil }
                let action = UIAction(title: String(localized: "Open Website"), image: UIImage(systemName: "safari")) { (action) in
                    self.openWebsite()
                }
                // We don't display subdomain like Website.simplifiedHost
                // to avoid multi-line subtitle as context menu item is displayed in narrow width
                action.subtitle = Self.hostnameParser.parse(websiteURL)?.rootDomain
                return action
            }()
        ].compactMap { $0 })
        
        let otherAppActionsMenu = UIMenu(title: "", options: .displayInline, children: [
            {
                guard actionTypes.contains(.openDirectionsInGoogleMaps) else { return nil }
                return UIAction(title: String(localized: "Google Maps"), image: UIImage(systemName: "g.circle.fill")) { (action) in
                    self.openDirectionsInGoogleMaps()
                }
            }(),
            {
                guard actionTypes.contains(.openDirectionsInYahooCarNavi) else { return nil }
                return UIAction(title: String(localized: "Yahoo! CarNavi"), image: UIImage(systemName: "y.circle.fill")) { (action) in
                    self.openDirectionsInYahooCarNavi()
                }
            }()
        ].compactMap { $0 })
        
        return UIMenu(children: [
            locationActionsMenu,
            otherAppActionsMenu
        ].filter { !$0.children.isEmpty })
    }
}
