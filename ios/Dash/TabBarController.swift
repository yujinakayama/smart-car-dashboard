//
//  TabBarController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/25.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    private var previousSelectedIndex: Int?

    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if selectedIndex == previousSelectedIndex, let tabReselectionRespondable = viewController as? TabReselectionRespondable {
            tabReselectionRespondable.tabBarControllerDidReselectAlreadyVisibleTab(self)
        }

        previousSelectedIndex = selectedIndex
    }
}

protocol TabReselectionRespondable {
    func tabBarControllerDidReselectAlreadyVisibleTab(_ tabBarController: UITabBarController)
}
