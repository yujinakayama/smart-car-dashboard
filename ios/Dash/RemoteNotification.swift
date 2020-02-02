//
//  RemoteNotification.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import DictionaryCoding

struct RemoteNotification {
    enum NotificationType: String {
        case share
    }

    let userInfo: [AnyHashable: Any]

    var type: NotificationType? {
        guard let string = userInfo["notificationType"] as? String else { return nil }
        return NotificationType(rawValue: string)
    }

    func process() throws {
        switch type {
        case .share:
            try ShareNotification(userInfo: userInfo).process()
        default:
            break
        }
    }
}

enum ItemNotificationError: Error {
    case unexpectedUserInfoStructure
}

struct ShareNotification {
    enum ItemType: String {
        case location
        case webpage
    }

    let itemDictionary: [String: Any]

    init(userInfo: [AnyHashable: Any]) throws {
        guard let itemDictionary = userInfo["item"] as? [String: Any] else {
            throw ItemNotificationError.unexpectedUserInfoStructure
        }

        self.itemDictionary = itemDictionary
    }

    func process() throws {
        let item = try SharedItem.makeItem(dictionary: itemDictionary)
        item.open()
    }
}
