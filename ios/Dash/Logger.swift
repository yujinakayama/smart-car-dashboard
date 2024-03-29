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
    let logger = XCGLogger(identifier: "default", includeDefaultDestinations: true)
    logger.setup(level: .verbose)
    logger.add(destination: fileDestination)
    return logger
}()

fileprivate let fileDestination: FileDestination = {
    let fileManager = FileManager.default

    let documentsDirectoryURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask).first!

    let logsDirectoryURL = documentsDirectoryURL.appendingPathComponent("Logs")

    if !fileManager.fileExists(atPath: logsDirectoryURL.absoluteString) {
        try! fileManager.createDirectory(at: logsDirectoryURL, withIntermediateDirectories: true)
    }

    let logFileURL = logsDirectoryURL.appendingPathComponent("log.txt")

    let destination = AutoRotatingFileDestination(
        writeToFile: logFileURL,
        shouldAppend: true,
        maxTimeInterval: 60 * 60 * 24,
        targetMaxLogFiles: 100
    )

    destination.outputLevel = Defaults.shared.logLevel

    return destination
}()
