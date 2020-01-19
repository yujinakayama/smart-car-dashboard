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
        guard let secondaryAsNavController = secondaryViewController as? UINavigationController else { return false }
        guard let topAsDetailController = secondaryAsNavController.topViewController as? ETCPaymentDetailViewController else { return false }
        if topAsDetailController.payment == nil {
            // Return true to indicate that we have handled the collapse by doing nothing; the secondary controller will be discarded.
            return true
        }
        return false
    }
}
