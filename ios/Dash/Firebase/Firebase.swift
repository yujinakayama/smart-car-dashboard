//
//  Firebase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseCore

class Firebase: NSObject {
    static let shared = Firebase()

    let authentication: FirebaseAuthentication
    let cloudMessaging: FirebaseCloudMessaging

    @objc dynamic var sharedItemDatabase: SharedItemDatabase?

    override init() {
        FirebaseApp.configure()

        // We instantiate Authentication here to invoke FirebaseApp.configure() first
        authentication = FirebaseAuthentication()
        cloudMessaging = FirebaseCloudMessaging()

        super.init()

        NotificationCenter.default.addObserver(self, selector: #selector(firebaseAuthenticationDidUpdateVehicleID), name: .FirebaseAuthenticationDidChangeVehicleID, object: nil)
    }

    @objc func firebaseAuthenticationDidUpdateVehicleID() {
        if let vehicleID = authentication.vehicleID {
            sharedItemDatabase = SharedItemDatabase(vehicleID: vehicleID)
            sharedItemDatabase?.startUpdating()
        } else {
            sharedItemDatabase = nil
        }
    }
}
