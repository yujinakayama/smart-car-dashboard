//
//  Cache.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/24.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import PINCache

// A cache class that abstracts PINCache and allows caching nil
class Cache {
    let pinCache: PINCache

    init(name: String, ageLimit: TimeInterval) {
        pinCache = PINCache(
            name: name,
            rootPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!,
            serializer: nil,
            deserializer: nil,
            keyEncoder: nil,
            keyDecoder: nil,
            ttlCache: true
        )
    }

    func containsObject(forKey key: String) -> Bool {
        return pinCache.containsObject(forKey: key)
    }

    func containsObject(forKeyAsync key: String, completion: @escaping (Bool) -> Void) {
        pinCache.containsObject(forKeyAsync: key, completion: completion)
    }

    func object(forKey key: String) -> Any? {
        let object = pinCache.object(forKey: key)

        if object is NSNull {
            return nil
        }

        return object
    }

    func object(forKeyAsync key: String, completion: @escaping (Any?) -> Void) {
        pinCache.object(forKeyAsync: key) { (cache, key, object) in
            if object is NSNull {
                completion(nil)
            } else {
                completion(object)
            }
        }
    }

    func setObject(_ object: Any?, forKey key: String) {
        let objectToCache = object == nil ? NSNull() : object
        pinCache.setObject(objectToCache, forKey: key)
    }

    func setObjectAsync(_ object: Any?, forKey key: String, completion: (() -> Void)? = nil) {
        let objectToCache = object == nil ? NSNull() : object

        pinCache.setObjectAsync(objectToCache as Any, forKey: key) { (cache, key, object) in
            completion?()
        }
    }
}
