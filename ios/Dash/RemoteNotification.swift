//
//  RemoteNotification.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import DictionaryCoding

class RemoteNotification {
    enum NotificationType: String {
        case share
    }

    let userInfo: [AnyHashable: Any]

    private var strongReferences: [Any] = []

    init(userInfo: [AnyHashable: Any]) {
        self.userInfo = userInfo
    }

    var type: NotificationType? {
        guard let string = userInfo["notificationType"] as? String else { return nil }
        return NotificationType(rawValue: string)
    }

    func process() {
        switch type {
        case .share:
            processShareNotification()
        default:
            break
        }
    }

    private func processShareNotification() {
        guard let itemDictionary = userInfo["item"] as? [String: Any] else {
            logger.error(userInfo)
            return
        }

        let item: SharedItemProtocol!

        do {
            item = try SharedItem.makeItem(dictionary: itemDictionary)
        } catch {
            logger.error(error)
            return
        }

        item.open()

        Firebase.shared.sharedItemDatabase?.findItem(identifier: item.identifier) { (item, error) in
            if let error = error {
                logger.error(error)
            }

            item?.markAsOpened()
        }

        strongReferences.append(item!)
    }
}
