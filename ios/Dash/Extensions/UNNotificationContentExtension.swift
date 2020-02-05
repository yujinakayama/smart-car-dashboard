//
//  UNNotificationContent.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UserNotifications

extension UNNotificationContent {
    struct UserInfoKey {
        static let foregroundPresentationOptions = "foregroundPresentationOptions"
    }

    @objc var foregroundPresentationOptions: UNNotificationPresentationOptions {
        get {
            if let rawValue = userInfo[UserInfoKey.foregroundPresentationOptions] as? UInt {
                return UNNotificationPresentationOptions(rawValue: rawValue)
            } else {
                return UNNotificationPresentationOptions()
            }
        }
    }
}

extension UNMutableNotificationContent {
    override var foregroundPresentationOptions: UNNotificationPresentationOptions {
        get {
            return super.foregroundPresentationOptions
        }

        set {
            userInfo[UserInfoKey.foregroundPresentationOptions] = newValue.rawValue
        }
    }
}
