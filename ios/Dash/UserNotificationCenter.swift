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
import FirebaseMessaging

class UserNotificationCenter: NSObject, UNUserNotificationCenterDelegate, MessagingDelegate {
    static let shared = UserNotificationCenter()

    let authorizationOptions: UNAuthorizationOptions = [.sound, .alert]
    let presentationOptions: UNNotificationPresentationOptions = [.sound, .alert]

    var notificationCenter: UNUserNotificationCenter {
        return UNUserNotificationCenter.current()
    }

    let notificationHistory = LatestUserNotificationHistory()

    override init() {
        super.init()
        notificationCenter.delegate = self
        Messaging.messaging().delegate = self
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

    func requestDelivery(_ notification: UserNotificationProtocol) {
        logger.info(notification)
        guard notification.shouldBeDelivered(history: notificationHistory) else { return }
        deliver(notification)
    }

    private func deliver(_ notification: UserNotificationProtocol) {
        logger.info(notification)

        UNUserNotificationCenter.current().add(notification.makeRequest()) { (error) in
            if let error = error {
                logger.error(error)
            }
        }

        notificationHistory.append(notification)
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        logger.info(notification)

        process(notification)

        notificationCenter.getNotificationSettings { [unowned self] (settings) in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                // Show the stock notification UI even when this app is in the foreground
                completionHandler(self.presentationOptions)
            default:
                return
            }
        }

        Messaging.messaging().appDidReceiveMessage(notification.request.content.userInfo)
    }

    func process(_ notification: UNNotification) {
        let userInfo = notification.request.content.userInfo

        guard let notificationType = userInfo["notificationType"] as? String, notificationType == "item" else { return }

        guard let item = userInfo["item"] as? [String: Any], let itemType = item["type"] as? String else { return }

        switch itemType {
        case "location":
            openInMaps(item: item)
        case "webpage":
            let url = URL(string: item["url"] as! String)!
            UIApplication.shared.open(url, options: [:])
        default:
            break
        }
    }

    func openInMaps(item: [String: Any]) {
        let coordinateItem = item["coordinate"] as! [String: Double]
        let coordinate = CLLocationCoordinate2D(
            latitude: CLLocationDegrees(coordinateItem["latitude"]!),
            longitude: CLLocationDegrees(coordinateItem["longitude"]!)
        )
        let placemark = MKPlacemark(coordinate: coordinate)

        let mapItem = MKMapItem(placemark: placemark)
        mapItem.name = item["name"] as? String

        if Defaults.shared.snapReceivedLocationToPointOfInterest {
            findPointOfInterest(for: mapItem) { (pointOfInterest) in
                if let pointOfInterest = pointOfInterest {
                    self.openDirectionsInMaps(to: pointOfInterest)
                } else {
                    self.openDirectionsInMaps(to: mapItem)
                }
            }
        } else {
            openDirectionsInMaps(to: mapItem)
        }
    }

    func findPointOfInterest(for mapItem: MKMapItem, completionHandler: @escaping (MKMapItem?) -> Void) {
        let request = MKLocalSearch.Request()
        request.naturalLanguageQuery = mapItem.name
        request.region = MKCoordinateRegion(center: mapItem.placemark.coordinate, latitudinalMeters: 50, longitudinalMeters: 50)

        MKLocalSearch(request: request).start { (response, error) in
            completionHandler(response?.mapItems.first)
        }
    }

    func openDirectionsInMaps(to mapItem: MKMapItem) {
        mapItem.openInMaps(launchOptions: [MKLaunchOptionsDirectionsModeKey: MKLaunchOptionsDirectionsModeDriving])
    }

    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String) {
        logger.debug(fcmToken)
        Messaging.messaging().subscribe(toTopic: "Dash")
    }
}

class LatestUserNotificationHistory {
    let dropOutTimeInterval: TimeInterval = 5

    private var notifications: [UserNotificationProtocol] = []

    func append(_ notification: UserNotificationProtocol) {
        notifications.append(notification)

        Timer.scheduledTimer(withTimeInterval: dropOutTimeInterval, repeats: false) { [weak self] (timer) in
            guard let self = self else { return }
            self.notifications.removeFirst()
        }
    }

    func contains(where predicate: (UserNotificationProtocol) -> Bool) -> Bool {
        return notifications.contains(where: predicate)
    }
}
