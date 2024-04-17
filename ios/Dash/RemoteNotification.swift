//
//  RemoteNotification.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
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
            Task {
                try await processShareNotification(context: context)
            }
        default:
            break
        }
    }

    private func processShareNotification(context: Context) async throws {
        guard let item = inboxItem,
              shouldOpen(item, context: context), // TODO: Make configurable
              let rootViewController =  rootViewController
        else { return }

        await item.open(from: rootViewController)

        guard let database = Firebase.shared.inboxItemDatabase,
              let documentID = documentID
        else { return }

        guard let itemInFirestore = try await database.item(documentID: documentID).get() else { return }
        itemInFirestore.markAsOpened(true)

        if let location = itemInFirestore as? InboxLocation,
           !location.categories.contains(where: { $0.isKindOfParking }),
           Defaults.shared.automaticallySearchParkingsWhenLocationIsAutomaticallyOpened
        {
            await InboxItemTableViewController.pushMapsViewControllerForParkingSearchInCurrentScene(location: location)
        }
    }

    private func shouldOpen(_ inboxItem: InboxItemProtocol, context: Context) -> Bool {
        switch context {
        case .openedByUser:
            return true
        case .receivedInForeground:
            if inboxItem is InboxLocation {
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

    private var documentID: String? {
        return userInfo["documentID"] as? String
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
