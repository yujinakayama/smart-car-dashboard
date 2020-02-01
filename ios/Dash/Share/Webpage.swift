//
//  Webpage.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/01.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

struct Webpage: SharedItem, Decodable {
    let title: String?
    let url: URL

    func open() {
        UIApplication.shared.open(url, options: [:])
    }
}
