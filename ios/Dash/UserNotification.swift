//
//  UserNotification.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/06/20.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import UserNotifications

protocol UserNotificationProtocol {
    var body: String { get }
    var sound: UNNotificationSound? { get }
    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool
}

extension UserNotificationProtocol {
    func makeRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = "ETC"
        content.body = body
        content.sound = sound

        return UNNotificationRequest(
            identifier: String(describing: type(of: self)),
            content: content,
            trigger: nil
        )
    }
}

struct TollgateEntranceNotification: UserNotificationProtocol {
    let body = "入口を通過しました。"

    let sound: UNNotificationSound? = UNNotificationSound(named: UNNotificationSoundName("Affirmative.wav"))

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return !history.contains { $0 is TollgateEntranceNotification || $0 is TollgateExitNotification }
    }
}

struct TollgateExitNotification: UserNotificationProtocol {
    let body = "出口を通過しました。"

    let sound: UNNotificationSound? = UNNotificationSound(named: UNNotificationSoundName("Affirmative.wav"))

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return !history.contains { $0 is TollgateEntranceNotification || $0 is TollgateExitNotification }
    }
}

struct PaymentNotification: UserNotificationProtocol {
    let amount: Int

    var body: String {
        return "料金は ¥\(amount) です。"
    }

    let sound: UNNotificationSound? = nil

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return true
    }
}
