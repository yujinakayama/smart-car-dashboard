//
//  Logger.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/11.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import XCGLogger

let logger: XCGLogger = {
    let logger = XCGLogger(identifier: "default")

    #if DEBUG
        logger.setup(level: .debug)
    #else
        logger.setup(level: .info)
    #endif

    return logger
}()
