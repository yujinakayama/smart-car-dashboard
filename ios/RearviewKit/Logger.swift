//
//  Logger.swift
//  Rearview
//
//  Created by Yuji Nakayama on 2020/09/13.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
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
