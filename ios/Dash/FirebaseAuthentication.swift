//
//  FirebaseAuthentication.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/10/31.
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

    static var vehicleID: String? {
        return Auth.auth().currentUser?.uid
    }

    private static var previousVehicleID: String?

    private static var authStateListener: AuthStateDidChangeListenerHandle?

    static func beginGeneratingVehicleIDNotifications() {
        guard authStateListener == nil else { return }

        previousVehicleID = vehicleID

        authStateListener = Auth.auth().addStateDidChangeListener { (auth, user) in
            logger.info("Current Firebase user: \(user?.email as String?)")

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
}
