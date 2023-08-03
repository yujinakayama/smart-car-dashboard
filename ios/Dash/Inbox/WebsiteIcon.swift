//
//  WebsiteIcon.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/02/15.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import SwiftSoup
import CacheKit

enum WebsiteIconError: Error {
    case invalidWebsiteURL
    case htmlEncodingError
    case unknown
}

actor WebsiteIcon {
    // 10MB, 30 days
    static let cache = Cache(name: "WebsiteIcon", byteLimit: 100 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 30)

    // Some websites such as YouTube provide less icon variants when accessed with mobile user agent.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15"
    
    let websiteURL: URL

    init(websiteURL: URL) {
        self.websiteURL = websiteURL
    }

    var image: UIImage? {
        get async {
            if isCached {
                return cachedImage
            }

            do {
                let image = try await fetchBestImage()
                cachedImage = image
                return image
            } catch is WebsiteIconError {
                cachedImage = nil // Cache the fact there's no valid icon
                return nil
            } catch {
                return nil
            }
        }
    }

    private var isCached: Bool {
        Self.cache.containsObject(forKey: cacheKey)
    }

    private (set) var cachedImage: UIImage? {
        get {
            return Self.cache.object(forKey: cacheKey) as? UIImage
        }

        set {
            Self.cache.setObject(newValue, forKey: cacheKey)
        }
    }

    private lazy var cacheKey: String = Cache.digestString(of: websiteURL.absoluteString)
    
    private func fetchBestImage() async throws -> UIImage? {
        let icons = try await extractIconsFromHTMLDocument()
        
        try Task.checkCancellation()

        if let appleIcon = icons.first(where: { $0.type == .apple }) {
            return try await fetchImage(from: appleIcon.url)
        }

        try Task.checkCancellation()

        if let image = try await fetchImage(from: fixedAppleTouchIconURL) {
            return image
        }

        try Task.checkCancellation()

        if let largestIcon = icons.max(by: { $0.largestSize < $1.largestSize }) {
            return try await fetchImage(from: largestIcon.url)
        }
        
        try Task.checkCancellation()

        return try await fetchImage(from: fixedFaviconURL)
    }

    private func extractIconsFromHTMLDocument() async throws -> [Icon]  {
        var request = URLRequest(url: websiteURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, _) = try await URLSession.shared.data(for: request)

        let document = try parseHTML(data: data)
        return try extractIcons(from: document)
    }

    private func parseHTML(data: Data) throws -> Document {
        guard let html = String(data: data, encoding: .utf8) else {
            throw WebsiteIconError.htmlEncodingError
        }

        return try SwiftSoup.parse(html, websiteURL.absoluteString)
    }

    private func extractIcons(from document: Document) throws -> [Icon] {
        let links = try document.select("link[rel~=apple-touch-icon], link[rel~=apple-touch-icon-precomposed], link[rel~=icon]")

        return links.compactMap { (link) -> Icon? in
            guard let href = try? link.attr("href"),
                  let iconURL = URL(string: href, relativeTo: websiteURL),
                  let rel = try? link.attr("rel")
            else { return nil }
            
            let type: IconType = rel.contains("apple") ? .apple : .generic
            
            // https://html.spec.whatwg.org/dev/semantics.html#attr-link-sizes
            let sizes: [Size]
            if let sizesString = try? link.attr("sizes") {
                sizes = sizesString.lowercased().components(separatedBy: .whitespaces).compactMap { sizeString -> Size? in
                    if sizeString == "any" {
                        return .any
                    }
                    
                    let dimensions = sizeString.components(separatedBy: "x").compactMap { Int($0) }
                    guard dimensions.count == 2 else { return nil }
                    
                    return .pixel(width: dimensions[0], height: dimensions[1])
                }
            } else {
                sizes = []
            }

            return Icon(url: iconURL, type: type, sizes: sizes)
        }
    }

    private func fetchImage(from url: URL) async throws -> UIImage? {
        let (data, _) = try await URLSession.shared.data(from: url)
        try Task.checkCancellation()
        return UIImage(data: data)
    }

    private var fixedAppleTouchIconURL: URL {
        get throws {
            guard var urlComponents = URLComponents(url: websiteURL, resolvingAgainstBaseURL: false) else {
                throw WebsiteIconError.invalidWebsiteURL
            }
            
            urlComponents.path = "/apple-touch-icon.png"
            urlComponents.query = nil
            return urlComponents.url!
        }
    }
    
    private var fixedFaviconURL: URL {
        get throws {
            guard var urlComponents = URLComponents(url: websiteURL, resolvingAgainstBaseURL: false) else {
                throw WebsiteIconError.invalidWebsiteURL
            }

            urlComponents.path = "/favicon.ico"
            urlComponents.query = nil
            return urlComponents.url!
        }
    }
}

extension WebsiteIcon {
    struct Icon {
        var url: URL
        var type: IconType
        var sizes: [Size]
        
        var largestSize: Size {
            sizes.max() ?? .unknown
        }
    }

    enum IconType {
        case apple
        case generic
    }
    
    enum Size: Comparable {
        case pixel(width: Int, height: Int)
        case any
        case unknown

        private var comparisonValue: Double {
            switch self {
            case .pixel(let width, let height):
                return Double(min(width, height))
            case .any:
                return .infinity
            case .unknown:
                return -1
            }
        }
        
        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.comparisonValue < rhs.comparisonValue
        }
    }
}
