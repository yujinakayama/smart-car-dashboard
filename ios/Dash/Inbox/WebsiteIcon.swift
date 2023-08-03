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
    case invalidURL
    case htmlEncodingError
    case unknown
}

actor WebsiteIcon {
    // 10MB, 30 days
    static let cache = Cache(name: "WebsiteIcon", byteLimit: 100 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 30)

    // Some websites such as YouTube provide less icon variants when accessed with mobile user agent.
    static let userAgent = "Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/605.1.15 (KHTML, like Gecko) Version/16.5 Safari/605.1.15"

    let websiteURL: URL
    let minimumSize: CGSize

    init(websiteURL: URL, minimumSize: CGSize) {
        self.websiteURL = websiteURL
        self.minimumSize = minimumSize
    }

    var image: UIImage? {
        get async {
            if await isCached {
                return await cachedImage
            }

            do {
                let image = try await fetchBestImage()
                setCachedImage(image)
                return image
            } catch is WebsiteIconError {
                setCachedImage(nil) // Cache the fact there's no valid icon
                return nil
            } catch {
                return nil
            }
        }
    }

    private var isCached: Bool {
        get async {
            await Self.cache.containsObject(forKey: cacheKey)
        }
    }

    private var cachedImage: UIImage? {
        get async {
            await Self.cache.object(forKey: cacheKey) as? UIImage
        }
    }

    private func setCachedImage(_ image: UIImage?) {
        Task {
            await Self.cache.setObject(image, forKey: cacheKey)
        }
    }

    private lazy var cacheKey: String = Cache.digestString(of: websiteURL.absoluteString)
    
    private func fetchBestImage() async throws -> UIImage? {
        let document = try await fetchHTMLDocument()
        let icons = try extractValidIcons(from: document)
        
        try Task.checkCancellation()

        if let appleIcon = icons.first(where: { $0.type == .apple }),
           let image = try await fetchValidImage(from: appleIcon.url)
        {
            return image
        }

        try Task.checkCancellation()

        if let image = try await fetchValidImage(from: fixedAppleTouchIconURL(documentURL: document.url)) {
            return image
        }

        try Task.checkCancellation()

        if let largestIcon = icons.max(by: { $0.largestSize < $1.largestSize }),
           let image = try await fetchValidImage(from: largestIcon.url)
        {
            return image
        }
        
        try Task.checkCancellation()

        if let image = try await fetchValidImage(from: fixedFaviconURL(documentURL: document.url)) {
            return image
        }

        try Task.checkCancellation()

        return try await fetchSquarishOGPImage(from: document)
    }

    private func fetchHTMLDocument() async throws -> HTMLDocument {
        var request = URLRequest(url: websiteURL)
        request.setValue(Self.userAgent, forHTTPHeaderField: "User-Agent")
        let (data, response) = try await URLSession.shared.data(for: request)

        guard let documentURL = response.url else {
            throw WebsiteIconError.unknown
        }

        guard let html = convertToStringByDetectingEncoding(from: data) else {
            throw WebsiteIconError.htmlEncodingError
        }

        return HTMLDocument(
            url: documentURL,
            document: try SwiftSoup.parse(html, documentURL.absoluteString)
        )
    }

    // https://stackoverflow.com/a/59843310
    private func convertToStringByDetectingEncoding(from data: Data) -> String? {
        var nsString: NSString?

        let encodingRawValue = NSString.stringEncoding(for: data, encodingOptions: nil, convertedString: &nsString, usedLossyConversion: nil)

        if encodingRawValue == 0 {
            return nil
        } else if let nsString = nsString {
            let encoding = String.Encoding(rawValue: encodingRawValue)
            logger.debug("Detected encoding \(encoding) (rawValue \(encodingRawValue)) for \(websiteURL)")
            return nsString as String
        } else {
            return nil
        }
    }
    
    private func extractValidIcons(from htmlDocument: HTMLDocument) throws -> [Icon]  {
        let links = try htmlDocument.document.select("link[rel~=apple-touch-icon], link[rel~=apple-touch-icon-precomposed], link[rel~=icon]")

        let icons = links.compactMap { (link) -> Icon? in
            guard let href = try? link.attr("href"),
                  let iconURL = URL(possiblyInvalidString: href, relativeTo: htmlDocument.url),
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

        return icons.filter { icon in
            if let size = icon.largestSize.cgSize {
                return size.isLargerThanOrEqualTo(minimumSize)
            } else {
                return true
            }
        }
    }

    private func fetchValidImage(from url: URL) async throws -> UIImage? {
        let (data, _) = try await URLSession.shared.data(from: url)

        try Task.checkCancellation()

        if let image = UIImage(data: data), image.size.isLargerThanOrEqualTo(minimumSize) {
            return image
        } else {
            return nil
        }
    }

    private func fixedAppleTouchIconURL(documentURL: URL) throws -> URL {
        guard var urlComponents = URLComponents(url: documentURL, resolvingAgainstBaseURL: false) else {
            throw WebsiteIconError.invalidURL
        }
        
        urlComponents.path = "/apple-touch-icon.png"
        urlComponents.query = nil
        return urlComponents.url!
    }
    
    private func fixedFaviconURL(documentURL : URL) throws -> URL {
        guard var urlComponents = URLComponents(url: documentURL, resolvingAgainstBaseURL: false) else {
            throw WebsiteIconError.invalidURL
        }

        urlComponents.path = "/favicon.ico"
        urlComponents.query = nil
        return urlComponents.url!
    }

    private func fetchSquarishOGPImage(from htmlDocument: HTMLDocument) async throws -> UIImage?  {
        guard let meta = try htmlDocument.document.select("meta[property='og:image']").first() else {
            return nil
        }

        guard let content = try? meta.attr("content"),
              let iconURL = URL(possiblyInvalidString: content, relativeTo: htmlDocument.url),
              let image = try await fetchValidImage(from: iconURL),
              (0.9...1.1).contains(image.size.width / image.size.height)
        else { return nil }

        return image
    }
}

extension WebsiteIcon {
    struct HTMLDocument {
        var url: URL
        var document: Document
    }

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

        var cgSize: CGSize? {
            if case .pixel(let width, let height) = self {
                return CGSize(width: width, height: height)
            } else {
                return nil
            }
        }
        
        static func < (lhs: Self, rhs: Self) -> Bool {
            lhs.comparisonValue < rhs.comparisonValue
        }

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
    }
}

fileprivate extension CGSize {
    func isLargerThanOrEqualTo(_ other: CGSize) -> Bool {
        self.rect.contains(other.rect)
    }
    
    var rect: CGRect {
        CGRect(origin: .zero, size: self)
    }
}

fileprivate extension URL {
    init?(possiblyInvalidString: String, relativeTo url: URL?) {
        if let url = URL(string: possiblyInvalidString, relativeTo: url) {
            self = url
            return
        }

        let trimmedString = possiblyInvalidString.trimmingCharacters(in: .whitespacesAndNewlines)
        
        // URL -> URLComponents -> URL fixes invalid URLs such as URL without percent encoding
        guard let components = URLComponents(string: trimmedString),
              let validString = components.string
        else { return nil }

        self.init(string: validString, relativeTo: url)
    }
}
