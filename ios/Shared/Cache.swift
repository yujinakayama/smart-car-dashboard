//
//  Cache.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/24.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import PINCache
import CommonCrypto

// A cache class that abstracts PINCache and allows caching nil
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

    let pinCache: PINCache

    public init(name: String, byteLimit: UInt, ageLimit: TimeInterval? = nil) {
        pinCache = PINCache(
            name: name,
            rootPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!,
            serializer: nil,
            deserializer: nil,
            keyEncoder: nil,
            keyDecoder: nil,
            ttlCache: ageLimit != nil
        )

        pinCache.diskCache.byteLimit = byteLimit

        if let ageLimit = ageLimit {
            pinCache.memoryCache.ageLimit = ageLimit
            pinCache.diskCache.ageLimit = ageLimit
        }
    }

    public func clear() {
        pinCache.removeAllObjects()
    }

    public func containsObject(forKey key: String) -> Bool {
        return pinCache.containsObject(forKey: key)
    }

    public func containsObject(forKeyAsync key: String, completion: @escaping (Bool) -> Void) {
        pinCache.containsObject(forKeyAsync: key, completion: completion)
    }

    public func object(forKey key: String) -> Any? {
        let object = pinCache.object(forKey: key)

        if object is NSNull {
            return nil
        }

        return object
    }

    public func object(forKeyAsync key: String, completion: @escaping (Any?) -> Void) {
        pinCache.object(forKeyAsync: key) { (cache, key, object) in
            if object is NSNull {
                completion(nil)
            } else {
                completion(object)
            }
        }
    }

    public func setObject(_ object: NSCoding?, forKey key: String) {
        let objectToCache = object == nil ? NSNull() : object
        pinCache.setObject(objectToCache, forKey: key)
    }

    public func setObjectAsync(_ object: NSCoding?, forKey key: String, completion: (() -> Void)? = nil) {
        let objectToCache = object == nil ? NSNull() : object

        pinCache.setObjectAsync(objectToCache as Any, forKey: key) { (cache, key, object) in
            completion?()
        }
    }
}
