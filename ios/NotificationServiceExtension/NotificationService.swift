//
//  NotificationService.swift
//  NotificationServiceExtension
//
//  Created by Yuji Nakayama on 2023/08/18.
//  Copyright © 2023 Yuji Nakayama. All rights reserved.
//

import UserNotifications

class NotificationService: UNNotificationServiceExtension {
    var contentHandler: ((UNNotificationContent) -> Void)?
    var bestAttemptContent: UNMutableNotificationContent?

    override func didReceive(_ request: UNNotificationRequest, withContentHandler contentHandler: @escaping (UNNotificationContent) -> Void) {
        self.contentHandler = contentHandler

        let mutableContent = (request.content.mutableCopy() as! UNMutableNotificationContent)
        bestAttemptContent = mutableContent

        Task {
            let content = await process(content: mutableContent)
            contentHandler(content)
        }
    }

    func process(content: UNMutableNotificationContent) async -> UNNotificationContent {
        guard let notificationTypeRawValue = content.userInfo["notificationType"] as? String,
              let notificationType = NotificationType(rawValue: notificationTypeRawValue)
        else {
            return content
        }

        switch notificationType {
        case .lockDoors:
            return await processLockDoorsNotification(content: content)
        }
    }

    func processLockDoorsNotification(content: UNMutableNotificationContent) async -> UNNotificationContent {
        do {
            try await DoorLock().lock()
            content.title = ""
            content.body = "Dash Remoteからドアがロックされました。"
            content.sound = nil
            return content
        } catch {
            content.title = "ドアロック失敗"
            content.body = "Dash Remoteがドアがロックしようとしましたが失敗しました。"
            content.sound = .default
            return content
        }
    }

    override func serviceExtensionTimeWillExpire() {
        // Called just before the extension will be terminated by the system.
        // Use this as an opportunity to deliver your "best attempt" at modified content, otherwise the original push payload will be used.
        if let contentHandler = contentHandler, let bestAttemptContent =  bestAttemptContent {
            contentHandler(bestAttemptContent)
        }
    }
}

enum NotificationType: String {
    case lockDoors
}
