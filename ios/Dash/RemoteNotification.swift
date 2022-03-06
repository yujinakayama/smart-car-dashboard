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

    func process(context: Context) {
        switch type {
        case .share:
            processShareNotification(context: context)
        default:
            break
        }
    }

    private func processShareNotification(context: Context) {
        guard let item = inboxItem,
              shouldOpen(item, context: context), // TODO: Make configurable
              let rootViewController =  rootViewController
        else { return }

        Task {
            await item.open(from: rootViewController)
        }

        if let location = item as? Location,
           !location.categories.contains(where: { $0.isKindOfParking }),
           Defaults.shared.automaticallySearchParkingsWhenLocationIsAutomaticallyOpened
        {
            InboxItemTableViewController.pushMapsViewControllerForParkingSearchInCurrentScene(location: location)
        }

        Firebase.shared.inboxItemDatabase?.findItem(identifier: item.identifier) { (item, error) in
            if let error = error {
                logger.error(error)
            }

            item?.markAsOpened(true)
        }

        strongReference = item
    }

    private func shouldOpen(_ inboxItem: InboxItemProtocol, context: Context) -> Bool {
        switch context {
        case .openedByUser:
            return true
        case .receivedInForeground:
            if inboxItem is Location {
                return !Vehicle.default.isMoving
            } else {
                return true
            }
        }
    }

    private var inboxItem: InboxItemProtocol? {
        guard let itemDictionary = userInfo["item"] as? [String: Any] else {
            logger.error(userInfo)
            return nil
        }

        do {
            return try InboxItem.makeItem(dictionary: itemDictionary)
        } catch {
            logger.error(error)
            return nil
        }
    }

    var rootViewController: UIViewController? {
        return UIApplication.shared.foregroundWindowScene?.keyWindow?.rootViewController
    }
}

extension RemoteNotification {
    enum Context {
        case receivedInForeground
        case openedByUser
    }
}
