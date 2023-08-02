//
//  WebsiteIcon.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import Foundation
import SwiftSoup
import CacheKit

enum WebsiteIconError: Error {
    case invalidWebsiteURL
    case htmlEncodingError
    case unknown
}

class WebsiteIcon {
    typealias Icon = (type: IconType, url: URL, size: Int?)

    enum IconType {
        case apple
        case generic
    }

    // 10MB, 30 days
    static let cache = Cache(name: "WebsiteIcon", byteLimit: 10 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 30)

    let websiteURL: URL

    private (set) var cachedURL: URL? {
        get {
            return WebsiteIcon.cache.object(forKey: cacheKey) as? URL
        }

        set {
            WebsiteIcon.cache.setObject(newValue as NSURL?, forKey: cacheKey)
        }
    }

    var isCached: Bool {
        WebsiteIcon.cache.containsObject(forKey: cacheKey)
    }

    private lazy var cacheKey: String = Cache.digestString(of: websiteURL.absoluteString)

    private lazy var redirectionDisabler = RedirectionDisabler()

    init(websiteURL: URL) {
        self.websiteURL = websiteURL
    }

    var url: URL? {
        get async {
            if isCached {
                return cachedURL
            }

            do {
                let url = try await fetchIconURL()
                cachedURL = url
                return url
            } catch is WebsiteIconError {
                cachedURL = nil // Cache the fact there's no valid icon
                return nil
            } catch {
                return nil
            }
        }
    }

    private func fetchIconURL() async throws -> URL? {
        if let url = try await checkFixedAppleTouchIconURL() {
            return url
        }
        
        if let url = try await extractIconURLFromHTMLDocument() {
            return url
        }

        return try await checkFixedFaviconURL()
    }

    private func checkFixedAppleTouchIconURL() async throws -> URL? {
        guard var urlComponents = URLComponents(url: websiteURL, resolvingAgainstBaseURL: false) else {
            throw WebsiteIconError.invalidWebsiteURL
        }

        urlComponents.path = "/apple-touch-icon.png"
        urlComponents.query = nil
        let url = urlComponents.url!

        if try await checkExistenceOf(url: url) {
            return url
        } else {
            return nil
        }
    }

    private func extractIconURLFromHTMLDocument() async throws -> URL?  {
        var request = URLRequest(url: websiteURL)
        // Some websites such as YouTube provide less icon variants when accessed with mobile user agent.
        request.setValue("Mozilla/5.0 (Macintosh) AppleWebKit (KHTML, like Gecko) Safari", forHTTPHeaderField: "User-Agent")

        let (data, _) = try await URLSession.shared.data(for: request)

        let document = try parseHTML(data: data)

        return try extractBestIconURL(from: document)
    }

    private func parseHTML(data: Data) throws -> Document {
        guard let html = String(data: data, encoding: .utf8) else {
            throw WebsiteIconError.htmlEncodingError
        }

        return try SwiftSoup.parse(html, websiteURL.absoluteString)
    }

    private func extractBestIconURL(from document: Document) throws -> URL? {
        let icons = try extractIcons(from: document)

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

            return (best.size ?? 0) >= (current.size ?? 0) ? best : current
        }

        return bestIcon!.url
    }

    private func extractIcons(from document: Document) throws -> [Icon] {
        let links = try document.select("link[rel~=apple-touch-icon], link[rel~=apple-touch-icon-precomposed], link[rel~=icon]")

        return links.compactMap { (link) -> Icon? in
            guard let href = try? link.attr("href"),
                  let iconURL = URL(string: href, relativeTo: websiteURL),
                  let rel = try? link.attr("rel")
            else { return nil }

            let type: IconType = rel.contains("apple") ? .apple : .generic

            var size: Int?
            if let sizeString = try? link.attr("sizes").components(separatedBy: "x").first {
                size = Int(sizeString)
            }

            return (type, iconURL, size)
        }
    }
    
    private func checkFixedFaviconURL() async throws -> URL? {
        guard var urlComponents = URLComponents(url: websiteURL, resolvingAgainstBaseURL: false) else {
            throw WebsiteIconError.invalidWebsiteURL
        }

        urlComponents.path = "/favicon.ico"
        urlComponents.query = nil
        let url = urlComponents.url!

        if try await checkExistenceOf(url: url) {
            return url
        } else {
            return nil
        }
    }

    private func checkExistenceOf(url: URL) async throws -> Bool {
        var request = URLRequest(url: url)
        request.httpMethod = "HEAD"

        // Some websites such as Netflix redirects to "Not found" page with 200 status :(
        let (_, response) = try await URLSession.shared.data(for: request, delegate: redirectionDisabler)

        guard let response = response as? HTTPURLResponse else {
            throw WebsiteIconError.unknown
        }

        return response.isSuccessful
    }
}

fileprivate class RedirectionDisabler: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse, newRequest request: URLRequest) async -> URLRequest? {
        return nil
    }
}

private extension HTTPURLResponse {
    var isSuccessful: Bool {
        let classNumber = statusCode / 100
        return classNumber == 2
    }
}
