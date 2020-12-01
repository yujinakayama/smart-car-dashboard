//
//  FirebaseCloudMessaging.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseMessaging

class FirebaseCloudMessaging: NSObject {
    var deviceToken: Data? {
        get {
            return Messaging.messaging().apnsToken
        }

        set {
            Messaging.messaging().apnsToken = newValue
        }
    }

    override init() {
        super.init()
        Messaging.messaging().delegate = self
        NotificationCenter.default.addObserver(self, selector: #selector(firebaseAuthenticationDidUpdateVehicleID), name: .FirebaseAuthenticationDidChangeVehicleID, object: nil)
    }

    func markNotificationAsReceived(_ notification: UNNotification) {
        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
    }

    @objc func firebaseAuthenticationDidUpdateVehicleID(notification: Notification) {
        if let oldVehicleID = notification.userInfo?[FirebaseAuthentication.UserInfoKey.oldVehicleID] as? String {
            logger.info("Unsubscribing from Cloud Messaging topic \(oldVehicleID)")
            Messaging.messaging().unsubscribe(fromTopic: oldVehicleID)
        }

        if let newVehicleID = notification.userInfo?[FirebaseAuthentication.UserInfoKey.newVehicleID] as? String {
            logger.info("Subscribing to Cloud Messaging topic \(newVehicleID)")
            Messaging.messaging().subscribe(toTopic: newVehicleID)
        }
    }
}

extension FirebaseCloudMessaging: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        logger.debug(fcmToken)
    }
}
