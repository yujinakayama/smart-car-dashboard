//
//  GoogleSignInViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseAuth
import GoogleSignIn

class GoogleSignInViewController: UIViewController, GIDSignInDelegate {
    override func viewDidLoad() {
        super.viewDidLoad()

        GIDSignIn.sharedInstance().delegate = self
        GIDSignIn.sharedInstance().presentingViewController = self
    }

    @IBAction func signInWithGoogleButtonDidTap(_ sender: Any) {
        GIDSignIn.sharedInstance().signIn()
    }

    func sign(_ signIn: GIDSignIn!, didSignInFor user: GIDGoogleUser!, withError error: Error?) {
        if let error = error {
            logger.error(error)
            return
        }

        guard let googleAuthentication = user.authentication else { return }

        let firebaseCredential = GoogleAuthProvider.credential(
            withIDToken: googleAuthentication.idToken,
            accessToken: googleAuthentication.accessToken
        )

        signInToFirebase(with: firebaseCredential)
    }

    func sign(_ signIn: GIDSignIn!, didDisconnectWith user: GIDGoogleUser!, withError error: Error!) {
        if let error = error {
            logger.error(error)
        }

        logger.info(user)
    }

    func signInToFirebase(with credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if let error = error {
                logger.error(error)
                return
            }

            logger.info(authResult)

            self.dismiss(animated: true)
        }
    }
}
