//
//  RootViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2023/08/17.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UIKit

class RootViewController: UIViewController {
    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        DispatchQueue.main.async {
            self.presentAppropriateViewController()
        }
    }

    func presentAppropriateViewController() {
        if PairedVehicle.defaultVehicleID == nil {
            showPairingRequirement()
        } else {
            Account.default.checkSignInState { (signedIn) in
                if signedIn {
                    self.showMainView()
                } else {
                    self.showSignInWithApple()
                }
            }
        }
    }

    func showPairingRequirement() {
        performSegue(withIdentifier: "pairingRequirement", sender: nil)
    }

    func showSignInWithApple() {
        self.performSegue(withIdentifier: "signInWithApple", sender: nil)
    }

    func showMainView() {
        self.performSegue(withIdentifier: "main", sender: nil)
    }
}
