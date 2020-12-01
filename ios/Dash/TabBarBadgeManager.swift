//
//  TabBarBadgeManager.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class TabBarBadgeManager {
    enum TabBarItemTag: Int {
        case inbox = 2
    }

    let tabBarController: UITabBarController

    private var sharedItemDatabaseObservation: NSKeyValueObservation?

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

        NotificationCenter.default.addObserver(self, selector: #selector(sharedItemDatabaseDidUpdateItems), name: .SharedItemDatabaseDidUpdateItems, object: nil)
    }

    func sharedItemDatabaseDidChange() {
        if Firebase.shared.sharedItemDatabase == nil {
            inboxTabBarItem.badgeValue = nil
        }
    }

    @objc func sharedItemDatabaseDidUpdateItems(notification: Notification) {
        guard let database = Firebase.shared.sharedItemDatabase else { return }
        let unopenedCount = database.items.filter { !$0.hasBeenOpened }.count
        inboxTabBarItem.badgeValue = (unopenedCount == 0) ? nil : "\(unopenedCount)"
    }
}
