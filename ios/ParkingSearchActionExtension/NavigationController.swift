//
//  NavigationController.swift
//  ParkingSearchActionExtension
//
//  Created by Yuji Nakayama on 2021/05/28.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import UIKit

class NavigationController: UINavigationController {
    init() {
        super.init(rootViewController: ActionViewController())
    }

    required init?(coder aDecoder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }
}
