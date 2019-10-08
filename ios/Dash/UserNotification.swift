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
    var title: String? { get }
    var body: String? { get }
    var sound: UNNotificationSound? { get }
    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool
}

extension UserNotificationProtocol {
    func makeRequest() -> UNNotificationRequest {
        let content = UNMutableNotificationContent()
        content.title = title ?? ""
        content.body = body ?? ""
        content.sound = sound

        return UNNotificationRequest(
            identifier: String(describing: type(of: self)),
            content: content,
            trigger: nil
        )
    }
}

struct TollgateEntranceNotification: UserNotificationProtocol {
    let title: String? = "ETC"
    let body: String? = "入口を通過しました。"
    let sound: UNNotificationSound? = UNNotificationSound(named: UNNotificationSoundName("Affirmative.wav"))

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return !history.contains { $0 is TollgateEntranceNotification || $0 is TollgateExitNotification }
    }
}

struct TollgateExitNotification: UserNotificationProtocol {
    let title: String? = "ETC"
    let body: String? = "出口を通過しました。"
    let sound: UNNotificationSound? = UNNotificationSound(named: UNNotificationSoundName("Affirmative.wav"))

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return !history.contains { $0 is TollgateEntranceNotification || $0 is TollgateEntranceNotification }
    }
}

struct PaymentNotification: UserNotificationProtocol {
    var payment: ETCPaymentProtocol

    var title: String? {
        if payment.entranceTollbooth == payment.exitTollbooth {
            return payment.entranceTollbooth?.name
        } else {
            return "\(payment.entranceTollbooth?.name ?? "不明な料金所") → \(payment.exitTollbooth?.name ?? "不明な料金所")"
        }
    }

    var body: String? {
        return "ETC料金は ¥\(payment.amount) です。"
    }

    let sound: UNNotificationSound? = nil

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return true
    }
}
