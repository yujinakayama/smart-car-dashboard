//
//  Defaults.swift
//  Dash
//
//  Created by Yuji Nakayama on 2019/09/08.
//  Copyright © 2019 Yuji Nakayama. All rights reserved.
//

import Foundation

class Defaults {
    static var shared = Defaults()

    private let userDefaults = UserDefaults.standard

    private enum Key: String {
        case autoLockDoorsWhenLeave
    }

    private func bool(for key: Key) -> Bool {
        return userDefaults.bool(forKey: key.rawValue)
    }

    private func set(_ value: Bool, for key: Key) {
        userDefaults.setValue(value, forKey: key.rawValue)
    }
}

extension Defaults {
    var autoLockDoorsWhenLeave: Bool {
        get {
            return bool(for: .autoLockDoorsWhenLeave)
        }

        set {
            set(newValue, for: .autoLockDoorsWhenLeave)
        }
    }
}
