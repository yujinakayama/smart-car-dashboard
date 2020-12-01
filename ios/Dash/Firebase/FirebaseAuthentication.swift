//
//  FirebaseAuthentication.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseCore
import FirebaseAuth
import GoogleSignIn

extension Notification.Name {
    static let FirebaseAuthenticationDidChangeVehicleID = Notification.Name("FirebaseAuthenticationDidChangeVehicleID")
}

class FirebaseAuthentication: NSObject {
    struct UserInfoKey {
        static let oldVehicleID = "oldVehicleID"
        static let newVehicleID = "newVehicleID"
    }

    var vehicleID: String? {
        return Auth.auth().currentUser?.uid
    }

    var email: String? {
        return Auth.auth().currentUser?.email
    }

    private var previousVehicleID: String?

    private var authStateListener: AuthStateDidChangeListenerHandle?

    private var signInCompletionHandler: ((Error?) -> Void)?

    override init() {
        super.init()
        GIDSignIn.sharedInstance().clientID = FirebaseApp.app()?.options.clientID
        GIDSignIn.sharedInstance().delegate = self
        beginGeneratingNotifications()
    }

    func presentSignInViewController(in presentingViewController: UIViewController, completion: @escaping (Error?) -> Void) {
        GIDSignIn.sharedInstance().presentingViewController = presentingViewController
        signInCompletionHandler = completion
        GIDSignIn.sharedInstance().signIn()
    }

    func handle(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance().handle(url)
    }

    private func beginGeneratingNotifications() {
        guard authStateListener == nil else { return }

        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] (auth, user) in
            self?.authStateDidChange()
        }
    }

    private func authStateDidChange() {
        logger.info("Current Firebase user: \(email as String?)")

        if vehicleID != previousVehicleID {
            let userInfo = [
                UserInfoKey.oldVehicleID: previousVehicleID as Any,
                UserInfoKey.newVehicleID: vehicleID as Any
            ]

            NotificationCenter.default.post(name: .FirebaseAuthenticationDidChangeVehicleID, object: self, userInfo: userInfo)
        }

        previousVehicleID = vehicleID
    }
}

extension FirebaseAuthentication: GIDSignInDelegate {
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

    private func signInToFirebase(with credential: AuthCredential) {
        Auth.auth().signIn(with: credential) { [weak self] (authResult, error) in
            if let error = error {
                logger.error(error)
            } else {
                logger.info(authResult)
            }

            self?.signInCompletionHandler?(error)
        }
    }
}
