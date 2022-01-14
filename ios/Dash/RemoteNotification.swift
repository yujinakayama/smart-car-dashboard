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

    private var strongReference: Any?

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
        guard let item = sharedItem, let rootViewController =  rootViewController else { return }

        item.open(from: rootViewController)

        if let location = item as? Location,
           !location.categories.contains(.parking),
           Defaults.shared.automaticallySearchParkingsWhenLocationIsAutomaticallyOpened
        {
            SharedItemTableViewController.pushMapsViewControllerForParkingSearchInCurrentScene(location: location)
        }

        Firebase.shared.sharedItemDatabase?.findItem(identifier: item.identifier) { (item, error) in
            if let error = error {
                logger.error(error)
            }

            item?.markAsOpened(true)
        }

        strongReference = item
    }

    private var sharedItem: SharedItemProtocol? {
        guard let itemDictionary = userInfo["item"] as? [String: Any] else {
            logger.error(userInfo)
            return nil
        }

        do {
            return try SharedItem.makeItem(dictionary: itemDictionary)
        } catch {
            logger.error(error)
            return nil
        }
    }

    var rootViewController: UIViewController? {
        return UIApplication.shared.foregroundWindowScene?.keyWindow?.rootViewController
    }
}
