//
//  WebsiteIcon.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import SwiftSoup
import CommonCrypto

enum WebsiteIconError: Error {
    case invalidWebsiteURL
    case htmlEncodingError
    case iconNotFound
    case unknown
}

class WebsiteIcon {
    typealias Icon = (type: IconType, url: URL, size: Int?)

    enum IconType {
        case apple
        case generic
    }

    static let cache = Cache(name: "WebsiteIcon", ageLimit: 60 * 60 * 24 * 30) // 30 days

    let websiteURL: URL

    private (set) var cachedURL: URL? {
        get {
            return WebsiteIcon.cache.object(forKey: cacheKey) as? URL
        }

        set {
            WebsiteIcon.cache.setObjectAsync(newValue as Any, forKey: cacheKey)
        }
    }

    var isCached: Bool {
        WebsiteIcon.cache.containsObject(forKey: cacheKey)
    }

    private lazy var cacheKey: String = {
        let websiteURLData = websiteURL.absoluteString.data(using: .utf8)!
        var digest = [UInt8](repeating: 0, count: Int(CC_SHA1_DIGEST_LENGTH))

        _ = websiteURLData.withUnsafeBytes { (dataPointer) in
            CC_SHA1(dataPointer.baseAddress, CC_LONG(websiteURLData.count), &digest)
        }

        let hexDigest = digest.map { String(format: "%02x", $0) }.joined()

        return hexDigest
    }()

    init(websiteURL: URL) {
        self.websiteURL = websiteURL
    }

    func getURL(completionHandler: @escaping (URL?) -> Void) {
        if isCached {
            completionHandler(cachedURL)
            return
        }

        fetchIconURL { (result) in
            switch result {
            case .success(let url):
                self.cachedURL = url
                completionHandler(url)
            case .failure(let error) where error is WebsiteIconError:
                self.cachedURL = nil // Cache the fact there's no icon
                completionHandler(nil)
            default:
                completionHandler(nil)
            }
        }
    }

    private func fetchIconURL(completionHandler: @escaping (Result<URL, Error>) -> Void) {
        checkFixedIconURL { (result) in
            switch result {
            case .success:
                completionHandler(result)
            case .failure:
                self.fetchAndExtractIconURLFromHTMLDocument(completionHandler: completionHandler)
            }
        }
    }

    private func checkFixedIconURL(completionHandler: @escaping (Result<URL, Error>) -> Void) {
        guard var urlComponents = URLComponents(url: websiteURL, resolvingAgainstBaseURL: false) else {
            completionHandler(.failure(WebsiteIconError.invalidWebsiteURL))
            return
        }

        urlComponents.path = "/apple-touch-icon.png"

        let url = urlComponents.url!

        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        let task = URLSession.shared.dataTask(with: urlComponents.url!) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            guard let response = response as? HTTPURLResponse else {
                completionHandler(.failure(WebsiteIconError.unknown))
                return
            }

            if response.isSuccessful {
                completionHandler(.success(url))
            } else {
                completionHandler(.failure(WebsiteIconError.iconNotFound))
            }
        }

        task.resume()
    }

    private func fetchAndExtractIconURLFromHTMLDocument(completionHandler: @escaping (Result<URL, Error>) -> Void) {
        let task = URLSession.shared.dataTask(with: websiteURL) { (data, response, error) in
            if let error = error {
                completionHandler(.failure(error))
                return
            }

            do {
                if let url = try self.extractIconURL(from: data!) {
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

    private func extractIconURL(from data: Data) throws -> URL? {
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

private extension HTTPURLResponse {
    var isSuccessful: Bool {
        let classNumber = statusCode / 100
        return classNumber == 2
    }
}
