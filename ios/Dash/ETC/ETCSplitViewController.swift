//
//  ETCPaymentSplitViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/07/13.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCSplitViewController: UISplitViewController, UISplitViewControllerDelegate {
    var device: ETCDevice! {
        didSet {
            let cardTableViewController = masterNavigationController.viewControllers.first as! ETCCardTableViewController
            cardTableViewController.device = device
        }
    }

    var masterNavigationController: UINavigationController {
        return viewControllers.first as! UINavigationController
    }

    var detailNavigationController: UINavigationController? {
        get {
            if _detailNavigationController != nil {
                return _detailNavigationController
            } else if viewControllers.count == 2 {
                _detailNavigationController = (viewControllers.last! as! UINavigationController)
                return _detailNavigationController
            } else {
                return nil
            }
        }

        set {
            _detailNavigationController = newValue
        }
    }

    private weak var _detailNavigationController: UINavigationController?

    override func awakeFromNib() {
        delegate = self

        _ = detailNavigationController // Assign _detailNavigationController

        let detailNavigationItem = detailNavigationController?.topViewController?.navigationItem
        detailNavigationItem?.leftBarButtonItem = displayModeButtonItem
        detailNavigationItem?.leftItemsSupplementBackButton = true
    }

    func splitViewController(_ splitViewController: UISplitViewController, collapseSecondary secondaryViewController: UIViewController, onto primaryViewController: UIViewController) -> Bool {
        // Prevent primary UINavigationController from pushing the secondary map view onto itself
        // because basically we want to see the payment list rather than the map in the compact size class.
        return true
    }

    func splitViewController(_ splitViewController: UISplitViewController, separateSecondaryFrom primaryViewController: UIViewController) -> UIViewController? {
        return detailNavigationController
    }
}
