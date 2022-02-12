//
//  TabBarBadgeManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseFirestoreSwift

class TabBarBadgeManager {
    enum TabBarItemTag: Int {
        case inbox = 2
    }

    let tabBarController: UITabBarController

    private var sharedItemDatabaseObservation: NSKeyValueObservation?
    private var sharedItemQuerySubscription: FirestoreQuery<SharedItemProtocol>.CountSubscription?

    var tabBarItems: [UITabBarItem] {
        guard let viewControllers = tabBarController.viewControllers else { return [] }
        return viewControllers.map { $0.tabBarItem }
    }

    lazy var inboxTabBarItem: UITabBarItem = tabBarItems.first { TabBarItemTag(rawValue: $0.tag) == .inbox }!

    init(tabBarController: UITabBarController) {
        self.tabBarController = tabBarController

        sharedItemDatabaseObservation = Firebase.shared.observe(\.sharedItemDatabase, options: .initial) { [weak self] (firebase, change) in
            self?.sharedItemDatabaseDidChange()
        }
    }

    func sharedItemDatabaseDidChange() {
        if let database = Firebase.shared.sharedItemDatabase {
            sharedItemQuerySubscription = database.items(hasBeenOpened: false).subscribeToCountUpdates { [weak self] (result) in
                self?.onCountUpdates(result: result)
            }
        } else {
            sharedItemQuerySubscription = nil
            inboxTabBarItem.badgeValue = nil
        }
    }

    func onCountUpdates(result: Result<Int, Error>) {
        do {
            let count = try result.get()
            self.inboxTabBarItem.badgeValue = (count == 0) ? nil : "\(count)"
        } catch {
            logger.error(error)
        }
    }
}
