//
//  Assistant.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class Assistant {
    var autoLocationOpener: AutoLocationOpener?

    init() {
        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)
    }

    @objc func applicationWillEnterForeground() {
        print(#function)
        if Defaults.shared.automaticallyOpenUnopenedLocationWhenAppIsOpened {
            autoLocationOpener = AutoLocationOpener()
        } else {
            autoLocationOpener = nil
        }
    }
}

extension Assistant {
    class AutoLocationOpener {
        let startDate = Date()
        let timeoutTimeInterval: TimeInterval = 5
        var finished = false

        init() {
            logger.info()

            NotificationCenter.default.addObserver(self, selector: #selector(sharedItemDatabaseDidUpdateItems), name: .SharedItemDatabaseDidUpdateItems, object: nil)

            openUnopenedLocation()
        }

        @objc func sharedItemDatabaseDidUpdateItems() {
            logger.info()

            if Date().timeIntervalSince(startDate) < timeoutTimeInterval {
                openUnopenedLocation()
            }
        }

        @objc func openUnopenedLocation() {
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
