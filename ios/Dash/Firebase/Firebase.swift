//
//  Firebase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseCore
import FirebaseFirestore

class Firebase: NSObject {
    static let shared = Firebase()

    let authentication: FirebaseAuthentication
    let messaging: FirebaseMessaging

    @objc dynamic var inboxItemDatabase: InboxItemDatabase?

    override init() {
        FirebaseApp.configure()

        // We instantiate Authentication here to invoke FirebaseApp.configure() first
        authentication = FirebaseAuthentication()
        messaging = FirebaseMessaging()

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(firebaseAuthenticationDidUpdateVehicleID), name: .FirebaseAuthenticationDidChangeVehicleID, object: nil)

        clearFirestoreOfflineCacheIfNeeded()
    }

    @objc func firebaseAuthenticationDidUpdateVehicleID() {
        if let vehicleID = authentication.vehicleID {
            inboxItemDatabase = InboxItemDatabase(vehicleID: vehicleID)
        } else {
            inboxItemDatabase = nil
        }
    }

    private func clearFirestoreOfflineCacheIfNeeded() {
        guard Defaults.shared.clearFirestoreOfflineCacheOnNextLaunch else { return }

        Defaults.shared.clearFirestoreOfflineCacheOnNextLaunch = false

        Firestore.firestore().clearPersistence { (error) in
            logger.info("Finished with error: \(String(describing: error))")
        }
    }
}
