//
//  UUIDExtension.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/18.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import CommonCrypto

extension UUID {
    enum Version: Int {
        case v5 = 5
    }

    // https://stackoverflow.com/a/48076401/784241
    init(version: Version, namespace: UUID, name: Data) {
        var data = withUnsafePointer(to: namespace.uuid) { (pointer) in
            Data(bytes: pointer, count: MemoryLayout.size(ofValue: namespace.uuid))
        }

        data.append(name)

        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        data.withUnsafeBytes { (dataPointer) -> Void in
            switch version {
            case .v5:
                CC_SHA1(dataPointer.baseAddress, CC_LONG(data.count), &digest)
            }
        }

        // Set version bits
        digest[6] &= 0x0F
        digest[6] |= UInt8(version.rawValue) << 4

        // Set variant bits
        digest[8] &= 0x3F
        digest[8] |= 0x80

        self = NSUUID(uuidBytes: digest) as UUID
    }
}
