//
//  ETCPaymentSplitViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/13.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    var masterNavigationController: UINavigationController {
        return viewControllers.first as! UINavigationController
    }

    var detailNavigationController: UINavigationController? {
        if viewControllers.count == 2 {
            return (viewControllers.last! as! UINavigationController)
        } else {
            return nil
        }
    }

    override func awakeFromNib() {
        delegate = self

        let detailNavigationItem = detailNavigationController?.topViewController?.navigationItem
        detailNavigationItem?.leftBarButtonItem = displayModeButtonItem
        detailNavigationItem?.leftItemsSupplementBackButton = true
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        // Prevent primary UINavigationController from pushing the secondary map view onto itself
        // because basically we want to see the payment list rather than the map in the compact size class.
        return true
    }
}
