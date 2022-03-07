//
//  Cache.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/24.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import PINCache
import PINOperation
import CommonCrypto

// A cache class that abstracts PINDiskCache and allows caching nil
public class Cache {
    public static func digestString(of string: String) -> String {
        return digestString(of: string.data(using: .utf8)!)
    }

    public static func digestString(of data: Data) -> String {
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        _ = data.withUnsafeBytes { (dataPointer) in
            CC_SHA1(dataPointer.baseAddress, CC_LONG(data.count), &digest)
        }

        return digest.map { String(format: "%02x", $0) }.joined()
    }

    let pinCache: PINDiskCache

    public init(name: String, byteLimit: UInt, ageLimit: TimeInterval? = nil) {
        pinCache = PINDiskCache(
            name: name,
            prefix: PINDiskCachePrefix,
            rootPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!,
            serializer: nil,
            deserializer: nil,
            keyEncoder: nil,
            keyDecoder: nil,
            operationQueue: PINOperationQueue(maxConcurrentOperations: 10),
            ttlCache: ageLimit != nil
        )

        pinCache.byteLimit = byteLimit

        if let ageLimit = ageLimit {
            pinCache.ageLimit = ageLimit
        }
    }

    public func clear() {
        pinCache.removeAllObjects()
    }

    public func containsObject(forKey key: String) -> Bool {
        return pinCache.containsObject(forKey: key)
    }

    public func containsObject(forKey key: String) async -> Bool {
        return await pinCache.containsObject(forKeyAsync: key)
    }

    public func object(forKey key: String) -> Any? {
        let object = pinCache.object(forKey: key)

        if object is NSNull {
            return nil
        } else {
            return object
        }
    }

    public func object(forKey key: String) async -> Any? {
        let (_, _, object) = await pinCache.object(forKeyAsync: key)

        if object is NSNull {
            return nil
        } else {
            return object
        }
    }

    public func setObject(_ object: NSCoding?, forKey key: String) {
        let objectToCache = object == nil ? NSNull() : object
        pinCache.setObject(objectToCache, forKey: key)
    }

    public func setObject(_ object: NSCoding?, forKey key: String) async {
        let objectToCache: NSCoding

        if let object = object {
            objectToCache = object
        } else {
            objectToCache = NSNull()
        }

        await pinCache.setObjectAsync(objectToCache, forKey: key)
    }

    public func removeObject(forKey key: String) {
        pinCache.removeObject(forKey: key)
    }
}
