//
//  TabBarController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/07/25.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class TabBarController: UITabBarController, UITabBarControllerDelegate {
    enum Tab: Int {
        case dashboard
        case etc
        case inbox
        case maps
    }

    private var previousSelectedIndex: Int?

    func viewController(for tab: Tab) -> UIViewController? {
        return viewControllers?.first { $0.tabBarItem.tag == tab.rawValue }
    }

    func removeTab(_ tab: Tab) {
        viewControllers = viewControllers?.filter { $0.tabBarItem.tag != tab.rawValue }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        delegate = self

        NotificationCenter.default.addObserver(forName: .FirebaseAuthenticationDidChangeVehicleID, object: nil, queue: .main) { [weak self] (notification) in
            self?.presentSignInViewControllerIfNeeded()
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)

        DispatchQueue.main.async {
            self.presentSignInViewControllerIfNeeded()
        }
    }

    func presentSignInViewControllerIfNeeded() {
        guard Firebase.shared.authentication.vehicleID == nil else { return }
        performSegue(withIdentifier: "showSignIn", sender: self)
    }

    func tabBarController(_ tabBarController: UITabBarController, didSelect viewController: UIViewController) {
        if selectedIndex == previousSelectedIndex {
            let tabReselectionRespondable =
                (viewController as? TabReselectionRespondable) ??
                (viewController as? UINavigationController)?.topViewController as? TabReselectionRespondable
            tabReselectionRespondable?.tabBarControllerDidReselectAlreadyVisibleTab(self)
        }

        previousSelectedIndex = selectedIndex
    }
}

protocol TabReselectionRespondable {
    func tabBarControllerDidReselectAlreadyVisibleTab(_ tabBarController: UITabBarController)
}
