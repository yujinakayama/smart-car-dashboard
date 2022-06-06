//
//  MusicItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/16.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import FirebaseFirestore
import MediaPlayer
import StoreKit

class Video: InboxItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let creator: String?
    let title: String?
    let url: URL
    let thumbnailURL: URL?
    let creationDate: Date?
    var hasBeenOpened: Bool

    func open(from viewController: UIViewController) async {
        openInDefaultApp()
    }
}
