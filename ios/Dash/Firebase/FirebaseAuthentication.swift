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

    private lazy var googleSignInConfiguration = GIDConfiguration(clientID: FirebaseApp.app()!.options.clientID!)

    override init() {
        super.init()
        beginGeneratingNotifications()
    }

    func presentSignInViewController(in presentingViewController: UIViewController, completion: @escaping (Error?) -> Void) {
        GIDSignIn.sharedInstance.signIn(with: googleSignInConfiguration, presenting: presentingViewController) { [weak self] (user, error) in
            guard let self = self else { return }

            if let error = error {
                logger.error(error)
                completion(error)
                return
            }

            guard let googleAuthentication = user?.authentication,
                  let idToken = googleAuthentication.idToken
            else { return }

            let firebaseCredential = GoogleAuthProvider.credential(
                withIDToken: idToken,
                accessToken: googleAuthentication.accessToken
            )

            self.signInToFirebase(with: firebaseCredential, completion: completion)
        }
    }

    private func signInToFirebase(with credential: AuthCredential, completion: @escaping (Error?) -> Void) {
        Auth.auth().signIn(with: credential) { (authResult, error) in
            if let error = error {
                logger.error(error)
            } else {
                logger.info(authResult)
            }

            completion(error)
        }
    }

    func signOut() {
        do {
            try Auth.auth().signOut()
        } catch {
            logger.error(error)
        }
    }

    func handle(_ url: URL) -> Bool {
        return GIDSignIn.sharedInstance.handle(url)
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
