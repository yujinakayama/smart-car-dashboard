//
//  GoogleSignInViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class GoogleSignInViewController: UIViewController {
    @IBAction func signInWithGoogleButtonDidTap(_ sender: Any) {
        Firebase.shared.authentication.presentSignInViewController(in: self) { (error) in
            self.dismiss(animated: true)
        }
    }
}
