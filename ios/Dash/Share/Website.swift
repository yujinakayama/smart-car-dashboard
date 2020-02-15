//
//  Webpage.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import FirebaseFirestore

class Website: SharedItemProtocol {
    var firebaseDocument: DocumentReference?

    let title: String?
    let url: URL
    let creationDate: Date?

    lazy var icon = WebsiteIcon(websiteURL: url)

    func open() {
        UIApplication.shared.open(url, options: [:])
    }
}
