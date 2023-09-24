//
//  OfficialParkingSearch.swift
//  ParkingSearchKit
//
//  Created by Yuji Nakayama on 2021/07/05.
//  Copyright © 2021 Yuji Nakayama. All rights reserved.
//

import Foundation
import WebKit
import MapKit
import CacheKit
import DashCloudKit

public protocol OfficialParkingSearchDelegate: NSObjectProtocol {
    func officialParkingSearch(_ officialParkingSearch: OfficialParkingSearch, didChange state: OfficialParkingSearch.State)
}

public class OfficialParkingSearch: NSObject {
    // 10MB, 7 days
    public static let cache = Cache(name: "OfficialParkingSearch", byteLimit: 10 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 7)

    private static let messageHandlerName = "OfficialParkingSearch"

    public let destination: MKMapItem
    public let webViewConfiguration: WKWebViewConfiguration

    public private (set) var state: State = .idle {
        didSet {
            if state != oldValue {
                delegate?.officialParkingSearch(self, didChange: state)
            }
        }
    }

    public weak var delegate: OfficialParkingSearchDelegate?

    private let cloudClient = DashCloudClient()

    private lazy var cacheKey: String = {
        let coordinate = destination.placemark.coordinate
        let key = String(format: "%@|%f,%f", destination.name!, coordinate.latitude, coordinate.longitude)
        return Cache.digestString(of: key)
    }()

    private var cachedURL: URL? {
        get {
            return Self.cache.object(forKey: cacheKey) as? URL
        }

        set {
            Self.cache.setObject(newValue as NSURL?, forKey: cacheKey)
        }
    }

    public init(destination: MKMapItem, webViewConfiguration: WKWebViewConfiguration) throws {
        if destination.name == nil || destination.name?.isEmpty == true {
            throw OfficialParkingSearchError.destinationMustHaveName
        }

        self.destination = destination
        self.webViewConfiguration = webViewConfiguration
        super.init()
    }

    deinit {
        stop()
    }

    public func start() {
        state = .searching

        if let cachedURL = cachedURL {
            load(url: cachedURL)
        } else {
            performSearch()
        }
    }

    public func stop() {
        webView.stopLoading()
    }

    private func performSearch() {
        cloudClient.searchOfficialParkings(for: destination) { [weak self] (result) in
            guard let self = self else { return }

            switch result {
            case .success(let webpage):
                cachedURL = webpage?.link

                if let webpage = webpage {
                    load(url: webpage.link)
                } else {
                    state = .notFound
                }
            case .failure(let error):
                logger.error(error)
                state = .error
            }
        }
    }

    private func load(url: URL) {
        logger.info(url.absoluteString)
        webView.load(URLRequest(url: url))
    }

    public lazy var webView = {
        let userContentController = WKUserContentController()
        userContentController.add(self, name: Self.messageHandlerName)
        userContentController.addUserScript(generateUserScriptForExtractingParkingDescription())
        webViewConfiguration.userContentController = userContentController

        let webView = WKWebView(frame: .zero, configuration: webViewConfiguration)
        webView.navigationDelegate = self
        return webView
    }()

    private func generateUserScriptForExtractingParkingDescription() -> WKUserScript {
        let scriptForExtractingParkingDescription = generateScriptForFindingBestElement(describing: "駐車場", callbackJavaScriptFunction: """
            (element) => {
                const postMessage = (message) => {
                    window.webkit.messageHandlers.\(Self.messageHandlerName).postMessage(message);
                };

                if (!element) {
                    postMessage(null);
                }

                const ancestorElementsOf = (baseElement) => {
                    const elements = [baseElement];
                    let element = baseElement;
                    while (element = element.parentElement) {
                        elements.push(element);
                    }
                    return elements;
                };

                const labelElement = ancestorElementsOf(element).find((e) => {
                    return ['DT', 'H1', 'H2', 'H3', 'H4', 'H5', 'H6', 'TD', 'TH'].includes(e.tagName);
                });

                if (!labelElement) {
                    postMessage(null);
                }

                const descriptionElement = labelElement.nextElementSibling;
                const description = descriptionElement?.innerText.trim() || descriptionElement?.textContent.trim();
                postMessage(description);
            }
        """)

        let script = """
            const extractParkingDescription = () => {
                \(scriptForExtractingParkingDescription)
            };

            if (["interactive", "complete"].includes(document.readyState)) {
                // Already DOMContentLoaded
                extractParkingDescription();
            } else {
                document.addEventListener("DOMContentLoaded", (event) => {
                    extractParkingDescription();
                });
            }
        """

        return WKUserScript(source: script, injectionTime: .atDocumentStart, forMainFrameOnly: true)
    }

    public func evaluateJavaScriptWithElementDescribingParking(_ javaScriptFunction: String, completion: @escaping (Result<Any, Error>) -> Void) {
        findBestElement(describing: "駐車場", andEvaluate: javaScriptFunction, completion: completion)
    }

    private func findBestElement(describing text: String, andEvaluate javaScriptFunction: String, completion: @escaping (Result<Any, Error>) -> Void) {
        let script = generateScriptForFindingBestElement(describing: text, callbackJavaScriptFunction: javaScriptFunction)

        webView.callAsyncJavaScript(
            script,
            in: nil,
            in: .defaultClient,
            completionHandler: completion
        )
    }

    private func generateScriptForFindingBestElement(describing searchText: String, callbackJavaScriptFunction: String) -> String {
        return """
            const searchText = \(escapeStringForJavaScript(searchText));
            const callbackSnippet = \(escapeStringForJavaScript(callbackJavaScriptFunction));

            function getElements(xpath) {
                const result = document.evaluate(xpath, document, null, XPathResult.ORDERED_NODE_SNAPSHOT_TYPE, null);

                const elements = [];

                for (let i = 0; i < result.snapshotLength; i++) {
                    elements.push(result.snapshotItem(i));
                }

                return elements;
            }

            const tagImportance = {
                H1: 100,
                H2: 99,
                H3: 98,
                H4: 97,
                H5: 96,
                H6: 95,
                TH: 30,
                DT: 29,
                TD: 20,
                DIV: 10,
                A: -10,
                SMALL: -20,
                FOOTER: -100,
            };

            function importanceOf(element) {
                return tagImportance[element.tagName] || 0;
            }

            function textLengthOf(element) {
                const text = element.innerText.trim() || element.textContent.trim();
                return text.length;
            }

            const xpath = `//body//*[text()[contains(., "${searchText}")]]`; // TODO: Escape searchText properly
            const elements = getElements(xpath);

            elements.sort((a, b) => {
                const result = importanceOf(b) - importanceOf(a);

                if (result !== 0) {
                    return result;
                }

                return textLengthOf(a) - textLengthOf(b);
            });

            const bestElement = elements[0];

            const callback = new Function(`return ${callbackSnippet}`).call();
            return callback(bestElement);
        """
    }
}

// https://stackoverflow.com/a/44942814/784241
extension WKNavigationActionPolicy {
    static let allowWithoutTryingAppLink = Self.init(rawValue: Self.allow.rawValue + 2)!
}

extension OfficialParkingSearch: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, decidePolicyFor navigationAction: WKNavigationAction, decisionHandler: @escaping (WKNavigationActionPolicy) -> Void) {
        // Requests initiated without user action
        if navigationAction.navigationType == .other {
            // Prevent opening universal link URLs in other apps (e.g. Tabelog)
            decisionHandler(.allowWithoutTryingAppLink)
        } else {
            // If the user explicitly wants to open the link in other app, it's OK.
            decisionHandler(.allow)
        }
    }
}

extension OfficialParkingSearch: WKScriptMessageHandler {
    public func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard state == .searching, let url = webView.url else { return }

        logger.info(message.body)
        let parkingInformation = ParkingInformation(url: url, description: message.body as? String)
        state = .found(parkingInformation)
    }
}

extension OfficialParkingSearch {
    public enum State: Equatable {
        case idle
        case searching
        case error
        case found(ParkingInformation)
        case notFound
    }
}

extension OfficialParkingSearch {
    public class ParkingInformation: Equatable {
        public static func == (lhs: OfficialParkingSearch.ParkingInformation, rhs: OfficialParkingSearch.ParkingInformation) -> Bool {
            return lhs.url == rhs.url && lhs.description == rhs.description
        }

        public let url: URL
        public let description: String?

        init(url: URL, description: String? = nil) {
            self.url = url
            self.description = description
        }

        lazy var existence: Bool? = { () -> Bool? in
            guard let sentences = sentences else { return nil }

            let existences: [Bool] = sentences.map { (sentence) in
                if let match = sentence.wholeMatch(of: /(有り?|あり)|(無し?|なし)/) {
                    return match.1 != nil
                } else {
                    return nil
                }
            }.compactMap { $0 }

            if existences.count == 1, let existence = existences.first {
                return existence
            } else {
                return nil
            }
        }()

        public lazy var capacity: Int? = { () -> Int? in
            if existence == false {
                return nil
            }

            guard let normalizedDescription = normalizedDescription else { return nil }

            let capacities: [Int] = normalizedDescription.matches(of: /(\d+,)台/).map { (match) in
                return Int(match.1)
            }.compactMap { $0 }

            if capacities.count == 1, let capacity = capacities.first {
                return capacity
            } else {
                return nil
            }
        }()

        private lazy var sentences: [String]? = {
            guard let normalizedDescription = normalizedDescription else { return nil }
            let sentences = normalizedDescription.split(separator: /\s*[。\n\(\)（）【】]\s*/)
            return sentences.map { String($0) }
        }()

        private lazy var normalizedDescription = description?.covertFullwidthAlphanumericsToHalfwidth().convertFullwidthWhitespacesToHalfwidth()
    }
}

enum OfficialParkingSearchError: Error {
    case destinationMustHaveName
    case webViewMustBeAddedToWindowButNoKeyWindowIsAvailable
}

fileprivate func escapeStringForJavaScript(_ string: String) -> String {
    let data = try! JSONEncoder().encode(string)
    return String(data: data, encoding: .utf8)!
}
