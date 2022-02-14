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

    let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!
    let logsDirectoryURL = documentsDirectoryURL.appendingPathComponent("Logs")
    if !fileManager.fileExists(atPath: logsDirectoryURL.absoluteString) {
        try! fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    }
    let logFileURL = logsDirectoryURL.appendingPathComponent("log.txt")
    let fileDestination = AutoRotatingFileDestination(
        writeToFile: logFileURL,
        shouldAppend: true,
        maxTimeInterval: 60 * 60 * 24,
        targetMaxLogFiles: 100
    )

    let logger = XCGLogger(identifier: "default", includeDefaultDestinations: true)
    logger.add(destination: fileDestination)
    logger.setup(level: .verbose, fileLevel: Defaults.shared.logLevel)

    return logger
}()
