//
//  UserNotificationManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/03.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import UIKit
import UserNotifications
import MapKit

class UserNotificationCenter: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UserNotificationCenter()

    let authorizationOptions: UNAuthorizationOptions = [.sound, .alert]

    var notificationCenter: UNUserNotificationCenter {
        return UNUserNotificationCenter.current()
    }

    let localNotificationHistory = LatestLocalNotificationHistory()

    override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func setUp() {
        requestAuthorization()
        UIApplication.shared.registerForRemoteNotifications()
    }

    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: authorizationOptions) { (granted, error) in
            logger.info((granted, error))
        }
    }

    func requestDelivery(_ notification: LocalNotificationProtocol) {
        logger.info(notification)
        guard notification.shouldBeDelivered(history: localNotificationHistory) else { return }
        deliver(notification)
    }

    private func deliver(_ notification: LocalNotificationProtocol) {
        logger.info(notification)

        UNUserNotificationCenter.current().add(notification.makeRequest()) { (error) in
            if let error = error {
                logger.error(error)
            }
        }

        localNotificationHistory.append(notification)
    }

    // User tapped received notification either in foreground or background
    func userNotificationCenter(_ center: UNUserNotificationCenter, didReceive response: UNNotificationResponse, withCompletionHandler completionHandler: @escaping () -> Void) {
        logger.info(response.notification.request.content)

        Firebase.shared.messaging.markNotificationAsReceived(response.notification)

        process(response.notification)

        completionHandler()
    }

    // Received notification in foreground
    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info(notification)

        process(notification)

        completionHandler(notification.request.content.foregroundPresentationOptions)
    }

    private var processingNotification: RemoteNotification?

    func process(_ notification: UNNotification) {
        let remoteNotification = RemoteNotification(userInfo: notification.request.content.userInfo)
        remoteNotification.process()
        processingNotification = remoteNotification
    }
}

class LatestLocalNotificationHistory {
    let dropOutTimeInterval: TimeInterval = 5

    private var notifications: [LocalNotificationProtocol] = []
    private lazy var dispatchQueue = DispatchQueue(label: "LatestLocalNotificationHistory")
    private var dropOutTimers: [DispatchSourceTimer] = []

    func append(_ notification: LocalNotificationProtocol) {
        notifications.append(notification)
        removeNotificationLater()
    }

    func contains(where predicate: (LocalNotificationProtocol) -> Bool) -> Bool {
        return notifications.contains(where: predicate)
    }

    private func removeNotificationLater() {
        let timer = DispatchSource.makeTimerSource(flags: [], queue: dispatchQueue)
        dropOutTimers.append(timer)

        timer.setEventHandler { [weak self] in
            guard let self = self else { return }
            self.notifications.removeFirst()
            self.dropOutTimers.removeFirst()
        }

        timer.schedule(deadline: .now() + dropOutTimeInterval)
        timer.resume()
    }
}
