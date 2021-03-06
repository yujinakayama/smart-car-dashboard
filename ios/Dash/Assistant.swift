//
//  Assistant.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class Assistant {
    var locationOpener: LocationOpener?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func applicationWillEnterForeground() {
        if Defaults.shared.automaticallyOpensUnopenedLocationWhenAppIsOpened {
            locationOpener = LocationOpener()
            locationOpener?.start()
        } else {
            locationOpener = nil
        }
    }
}

extension Assistant {
    class LocationOpener {
        let startDate = Date()
        let timeoutTimeInterval: TimeInterval = 5
        var finished = false

        func start() {
            NotificationCenter.default.addObserver(self, selector: #selector(sharedItemDatabaseDidUpdateItems), name: .SharedItemDatabaseDidUpdateItems, object: nil)
        }

        @objc func sharedItemDatabaseDidUpdateItems() {
            logger.info()

            if Date().timeIntervalSince(startDate) < timeoutTimeInterval {
                openUnopenedLocationIfNeeded()
            }
        }

        private func openUnopenedLocationIfNeeded() {
            logger.info()

            guard !finished else { return }

            guard let database = Firebase.shared.sharedItemDatabase else { return }
            let unopenedLocations = database.items.filter { $0 is Location && !$0.hasBeenOpened }
            guard unopenedLocations.count == 1, let location = unopenedLocations.first else { return }
            location.open(from: nil)

            finished = true
        }
    }
}
