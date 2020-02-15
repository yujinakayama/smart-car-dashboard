//
//  WebsiteIcon.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import SwiftSoup
import PINCache

enum WebsiteIconError: Error {
    case htmlEncodingError
    case iconNotFound
}

class WebsiteIcon {
    typealias Icon = (type: IconType, url: URL, size: Int?)

    enum IconType {
        case apple
        case generic
    }

    private static let cache = PINCache(
        name: "WebsiteIcon",
        rootPath: NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true).first!,
        serializer: nil,
        deserializer: nil,
        keyEncoder: nil,
        keyDecoder: nil,
        ttlCache: true
    )

    let websiteURL: URL

    private (set) var url: URL? {
        get {
            return cache.object(forKey: websiteURL.absoluteString) as? URL
        }

        set {
            if let url = newValue {
                cache.setObjectAsync(url, forKey: websiteURL.absoluteString, withAgeLimit: cacheAgeLimit)
            } else {
                cache.removeObject(forKeyAsync: websiteURL.absoluteString)
            }
        }
    }

    private var cache: PINCache {
        return WebsiteIcon.cache
    }

    private let cacheAgeLimit: TimeInterval = 60 * 60 * 24 * 30 // 30 days

    init(websiteURL: URL) {
        self.websiteURL = websiteURL
    }

    func getURL(completionHandler: @escaping (Result<URL, Error>) -> Void) {
        if let url = url {
            completionHandler(.success(url))
        } else {
            fetchURL { (result) in
                if case .success(let url) = result {
                    self.url = url
                }

                completionHandler(result)
            }
        }
    }

    private func fetchURL(completionHandler: @escaping (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: websiteURL) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            do {
                if let url = try self.extractURL(from: data!) {
                    completionHandler(.success(url))
                } else {
                    completionHandler(.failure(WebsiteIconError.iconNotFound))
                }
            } catch {
                completionHandler(.failure(error))
            }
        }

        task.resume()
    }

    private func extractURL(from data: Data) throws -> URL? {
        let icons = try extractIcons(from: data)

        guard !icons.isEmpty else { return nil }

        let bestIcon = icons.reduce(nil) { (best, current) -> Icon in
            guard let best = best else {
                return current
            }

            if best.type == .apple && current.type != .apple {
                return best
            }

            if best.type != .apple && current.type == .apple {
                return current
            }

            guard let currentSize = current.size else {
                return best
            }

            guard let bestSize = best.size else {
                return current
            }

            return bestSize >= currentSize ? best : current
        }

        return bestIcon!.url
    }

    private func extractIcons(from data: Data) throws -> [Icon] {
        guard let html = String(data: data, encoding: .utf8) else {
            throw WebsiteIconError.htmlEncodingError
        }

        let document = try SwiftSoup.parse(html, websiteURL.absoluteString)
        let links = try document.select("link[rel='apple-touch-icon'], link[rel='apple-touch-icon-precomposed'], link[rel='icon']")

        return links.compactMap { (link) -> Icon? in
            guard let href = try? link.attr("href"), let iconURL = URL(string: href, relativeTo: websiteURL) else { return nil }

            let rel = try! link.attr("rel")
            let type: IconType = rel.contains("apple") ? .apple : .generic

            var size: Int?
            if let sizesString = try? link.attr("sizes") {
                size = Int(sizesString.components(separatedBy: "x").first!)
            }

            return (type, iconURL, size)
        }
    }
}
