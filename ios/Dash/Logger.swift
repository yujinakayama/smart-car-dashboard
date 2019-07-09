//
//  Logger.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/06/18.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import XCGLogger

let logger: XCGLogger = {
    let fileManager = FileManager.default

    let applicationSupportDirectoryURL = fileManager.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
    if !fileManager.fileExists(atPath: applicationSupportDirectoryURL.absoluteString) {
        try! fileManager.createDirectory(at: applicationSupportDirectoryURL, withIntermediateDirectories: true)
    }

    let logFileURL = applicationSupportDirectoryURL.appendingPathComponent("log.txt")
    let destination = FileDestination(writeToFile: logFileURL, shouldAppend: true)

    let logger = XCGLogger(identifier: "default", includeDefaultDestinations: true)
    logger.add(destination: destination)
    logger.setup(level: .debug, fileLevel: .debug)
    return logger
}()
