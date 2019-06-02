//
//  UserNotificationManager.swift
//  ETC
//
//  Created by Yuji Nakayama on 2019/06/03.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import UserNotifications

class UserNotificationManager: NSObject, UNUserNotificationCenterDelegate {
    static let shared = UserNotificationManager()

    let authorizationOptions: UNAuthorizationOptions = [.sound, .alert]
    let presentationOptions: UNNotificationPresentationOptions = [.sound, .alert]

    var notificationCenter: UNUserNotificationCenter {
        return UNUserNotificationCenter.current()
    }

    override init() {
        super.init()
        notificationCenter.delegate = self
    }

    func requestAuthorization() {
        notificationCenter.requestAuthorization(options: authorizationOptions) { (granted, error) in
            print("\(#function): \(granted), \(error as Error?)")
        }
    }

    func deliverNotification(title: String) {
        let request = makeNotificationRequest(title: title)

        UNUserNotificationCenter.current().add(request) { (error) in
            if let error = error {
                print("\(#function): \(error)")
            }
        }
    }

    private func makeNotificationRequest(title: String) -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title
        content.sound = UNNotificationSound(named: UNNotificationSoundName("Affirmative.wav"))

        return UNNotificationRequest(
            identifier: "me.yujinakayama.ETC",
            content: content,
            trigger: nil
        )
    }

    func userNotificationCenter(_ center: UNUserNotificationCenter, willPresent notification: UNNotification, withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void) {
        notificationCenter.getNotificationSettings { [unowned self] (settings) in
            switch settings.authorizationStatus {
            case .authorized, .provisional:
                // Show the stock notification UI even when this app is in the foreground
                completionHandler(self.presentationOptions)
            default:
                return
            }
        }
    }
}
