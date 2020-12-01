//
//  Firebase.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseCore

class Firebase {
    static let shared = Firebase()

    let authentication: FirebaseAuthentication
    let cloudMessaging: FirebaseCloudMessaging

    init() {
        FirebaseApp.configure()
        // We instantiate Authentication here to invoke FirebaseApp.configure() first
        authentication = FirebaseAuthentication()
        cloudMessaging = FirebaseCloudMessaging()
    }
}
