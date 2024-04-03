//
//  BrokenItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/02.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore

class UnknownItem: InboxItemProtocol {
    var firebaseDocument: DocumentReference?

    let url: URL
    let creationDate: Date?
    var hasBeenOpened: Bool

    var title: String? {
        return nil
    }

    func open(from viewController: UIViewController) {
        openInDefaultApp()
    }
}
