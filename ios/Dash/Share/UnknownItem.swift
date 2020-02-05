//
//  BrokenItem.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/02.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

struct UnknownItem: SharedItemProtocol {
    let url: URL
    let creationDate: Date?

    func open() {
    }
}
