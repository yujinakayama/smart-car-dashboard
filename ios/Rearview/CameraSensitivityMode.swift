//
//  CameraSensitivityMode.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2021/02/10.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation

enum CameraSensitivityMode: Int, CaseIterable {
    case auto = 0
    case day
    case night
    case lowLight
    case ultraLowLight
}
