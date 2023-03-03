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

    private var googleSignIn: GIDSignIn {
        return GIDSignIn.sharedInstance
    }

    override init() {
        super.init()
        configureGoogleSignIn()
        beginGeneratingNotifications()
    }

    func presentSignInViewController(in presentingViewController: UIViewController, completion: @escaping (Error?) -> Void) {
        googleSignIn.signIn(withPresenting: presentingViewController) { [weak self] (result, error) in
            guard let self = self else { return }

            if let error = error {
                logger.error(error)
                completion(error)
                return
            }

            guard let user = result?.user,
                  let idToken = user.idToken
            else { return }

            let firebaseCredential = GoogleAuthProvider.credential(
                withIDToken: idToken.tokenString,
                accessToken: user.accessToken.tokenString
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
        return googleSignIn.handle(url)
    }

    private func configureGoogleSignIn() {
        googleSignIn.configuration = GIDConfiguration(clientID: FirebaseApp.app()!.options.clientID!)
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
