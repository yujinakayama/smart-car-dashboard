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

struct TollgatePassingThroughNotification: UserNotificationProtocol {
    let title: String? = nil
    let body: String? = "ETCゲートを通過しました。"
    let sound: UNNotificationSound? = UNNotificationSound(named: UNNotificationSoundName("TollgatePassingThrough.wav"))

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return !history.contains { $0 is TollgatePassingThroughNotification }
    }
}

struct PaymentNotification: UserNotificationProtocol {
    static let amountNumberFormatter: NumberFormatter = {
        let formatter = NumberFormatter()
        formatter.numberStyle = .currency
        formatter.currencyCode = "JPY"
        return formatter
    }()

    var payment: ETCPaymentProtocol

    var title: String? {
        let entrance = payment.entranceTollbooth
        let exit = payment.exitTollbooth

        if entrance == exit {
            return [
                entrance?.road.abbreviatedName,
                entrance?.name ?? "不明な料金所"
            ].compactMap { $0 }.joined(separator: " ")
        } else {
            return [
                entrance?.road.abbreviatedName,
                entrance?.name ?? "不明な料金所",
                "→",
                entrance?.road.name == exit?.road.name ? nil : exit?.road.abbreviatedName,
                exit?.name ?? "不明な料金所"
            ].compactMap { $0 }.joined(separator: " ")
        }
    }

    var body: String? {
        return "\(jpyAmount) を支払いました。"
    }

    let sound: UNNotificationSound? = UNNotificationSound(named: UNNotificationSoundName("Payment.wav"))

    func shouldBeDelivered(history: LatestUserNotificationHistory) -> Bool {
        return true
    }

    var jpyAmount: String {
        let number = NSNumber(value: payment.amount)
        return PaymentNotification.amountNumberFormatter.string(from: number)!
    }
}
