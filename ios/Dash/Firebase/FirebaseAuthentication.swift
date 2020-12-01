//
//  FirebaseAuthentication.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseAuth

extension Notification.Name {
    static let FirebaseAuthenticationDidChangeVehicleID = Notification.Name("FirebaseAuthenticationDidChangeVehicleID")
}

class FirebaseAuthentication {
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

    init() {
        beginGeneratingNotifications()
    }

    private func beginGeneratingNotifications() {
        guard authStateListener == nil else { return }

        previousVehicleID = vehicleID

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
