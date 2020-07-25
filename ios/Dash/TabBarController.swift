//
//  TabBarController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/25.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()
        delegate = self
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if let tabSelectionRespondable = viewController as? TabSelectionRespondable {
            tabSelectionRespondable.tabDidSelect()
        }
    }
}

protocol TabSelectionRespondable {
    func tabDidSelect()
}
