//
//  Webpage.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseFirestore

class Website: InboxItemProtocol {
    var firebaseDocument: DocumentReference?
    var identifier: String!

    let title: String?
    let url: URL
    let creationDate: Date?
    var hasBeenOpened: Bool

    lazy var icon = WebsiteIcon(websiteURL: url)

    lazy var simplifiedHost = url.host?.replacingOccurrences(of: "^www\\d*\\.", with: "", options: .regularExpression)

    func open(from viewController: UIViewController) {
        openInInAppBrowser(from: viewController)
    }
}
