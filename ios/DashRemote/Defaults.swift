//
//  Defaults.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/09/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation
import XCGLogger

class Defaults {
    static var shared = Defaults()

    private let userDefaults = UserDefaults.standard

    private func bool(for key: Key) -> Bool {
        return userDefaults.bool(forKey: key.rawValue)
    }

    private func set(_ value: Bool, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func integer(for key: Key) -> Int {
        return userDefaults.integer(forKey: key.rawValue)
    }

    private func set(_ value: Int, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }

    private func string(for key: Key) -> String? {
        return userDefaults.string(forKey: key.rawValue)
    }

    private func set(_ value: Any?, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }
}

extension Defaults {
    private enum Key: String {
        case autoLockDoorsWhenLeave
        case logLevel
    }

    var autoLockDoorsWhenLeave: Bool {
        get {
            bool(for: .autoLockDoorsWhenLeave)
        }

        set {
            set(newValue, for: .autoLockDoorsWhenLeave)
        }
    }

    var logLevel: XCGLogger.Level {
        get {
            return XCGLogger.Level(rawValue: integer(for: .logLevel)) ?? .info
        }
    }
}
