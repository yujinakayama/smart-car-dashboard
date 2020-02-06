//
//  IndexPathExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/07.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation

extension IndexPath {
    func adding(section difference: Int) -> IndexPath {
        return IndexPath(row: row, section: section + difference)
    }
}
