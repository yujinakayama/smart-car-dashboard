//
//  ViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ViewController: UIViewController {

    override func viewDidLoad() {
        super.viewDidLoad()

        Account.default.checkSignInState { (signedIn) in
            if !signedIn {
                self.performSegue(withIdentifier: "signInWithApple", sender: nil)
            }
        }
    }
}
