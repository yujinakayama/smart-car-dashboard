//
//  Webpage.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

struct Webpage: SharedItemProtocol {
    let title: String?
    let url: URL
    let creationDate: Date?

    func open() {
        UIApplication.shared.open(url, options: [:])
    }
}
