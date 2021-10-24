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
        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)
        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)
    }

    @objc func sceneDidEnterBackground() {
        Defaults.shared.lastBackgroundEntranceTime = Date()
    }

    @objc func sceneWillEnterForeground() {
        if Defaults.shared.automaticallyOpensUnopenedLocationWhenAppIsOpened {
            locationOpener = LocationOpener(newItemThresholdTime: Defaults.shared.lastBackgroundEntranceTime)
            locationOpener?.start()
        } else {
            locationOpener = nil
        }
    }
}

extension Assistant {
    class LocationOpener {
        let newItemThresholdTime: Date
        let maxDatabaseUpdateWaitTimeInterval: TimeInterval = 5
        var finished = false
        private var location: Location?

        init(newItemThresholdTime: Date) {
            self.newItemThresholdTime = newItemThresholdTime
        }

        func start() {
            NotificationCenter.default.addObserver(self, selector: #selector(sharedItemDatabaseDidUpdateItems), name: .SharedItemDatabaseDidUpdateItems, object: nil)
            Timer.scheduledTimer(timeInterval: maxDatabaseUpdateWaitTimeInterval, target: self, selector: #selector(timeoutTimerDidFire), userInfo: nil, repeats: false)
        }

        @objc func sharedItemDatabaseDidUpdateItems() {
            logger.info()
            openUnopenedLocationIfNeeded()
        }

        @objc func timeoutTimerDidFire() {
            logger.info()
            NotificationCenter.default.removeObserver(self, name: .SharedItemDatabaseDidUpdateItems, object: nil)
            openUnopenedLocationIfNeeded()
        }

        private func openUnopenedLocationIfNeeded() {
            logger.info()

            guard !finished else { return }

            guard let database = Firebase.shared.sharedItemDatabase else { return }
            let unopenedLocations = database.items.filter { $0 is Location && !$0.hasBeenOpened && ($0.creationDate ?? Date()) > newItemThresholdTime } as! [Location]
            guard unopenedLocations.count == 1, let location = unopenedLocations.first else { return }
            location.open()
            self.location = location

            finished = true
        }
    }
}
