//
//  BrokenItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/02.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class UnknownItem: SharedItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let url: URL
    let creationDate: Date?
    var hasBeenOpened: Bool

    func open(from viewController: UIViewController?) {
        markAsOpened()
        openInOtherApp()
    }

    func openSecondarily(from viewController: UIViewController?) {
        openInInAppBrowser(from: viewController)
    }
}
