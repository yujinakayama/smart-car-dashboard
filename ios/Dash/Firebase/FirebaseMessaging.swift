//
//  FirebaseCloudMessaging.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseMessaging

class FirebaseMessaging: NSObject {
    var deviceToken: Data? {
        get {
            return Messaging.messaging().apnsToken
        }

        set {
            Messaging.messaging().apnsToken = newValue
            processPendingTopics()
        }
    }

    private var pendingTopicToUnsubscribe: String?
    private var pendingTopicToSubscribe: String?

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
            // Subscribing to a topic without APNS token fails
            if deviceToken == nil {
                pendingTopicToUnsubscribe = oldVehicleID
            } else {
                logger.info("Unsubscribing from Cloud Messaging topic \(oldVehicleID)")
                Messaging.messaging().unsubscribe(fromTopic: oldVehicleID) { (error) in
                    logger.error(error)
                }
            }
        }

        if let newVehicleID = notification.userInfo?[FirebaseAuthentication.UserInfoKey.newVehicleID] as? String {
            if deviceToken == nil {
                pendingTopicToSubscribe = newVehicleID
            } else {
                logger.info("Subscribing to Cloud Messaging topic \(newVehicleID)")
                Messaging.messaging().subscribe(toTopic: newVehicleID) { (error) in
                    logger.error(error)
                }
            }
        }
    }

    private func processPendingTopics() {
        if let topic = pendingTopicToUnsubscribe {
            logger.info("Unsubscribing from Cloud Messaging topic \(topic)")
            Messaging.messaging().unsubscribe(fromTopic: topic) { (error) in
                logger.error(error)
            }
            pendingTopicToUnsubscribe = nil
        }

        if let topic = pendingTopicToSubscribe {
            logger.info("Subscribing to Cloud Messaging topic \(topic)")
            Messaging.messaging().subscribe(toTopic: topic) { (error) in
                logger.error(error)
            }
            pendingTopicToSubscribe = nil
        }
    }
}

extension FirebaseMessaging: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        logger.debug(fcmToken)
    }
}
