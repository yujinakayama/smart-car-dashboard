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
import TLDExtract
import CommonCrypto

public protocol OfficialParkingSearchDelegate: NSObjectProtocol {
    func officialParkingSearch(_ officialParkingSearch: OfficialParkingSearch, didChange state: OfficialParkingSearch.State)
}

public class OfficialParkingSearch: NSObject {
    static let excludedDomains = [
        "akippa.com",
        "earth-car.com",
        "its-mo.com",
        "mapfan.com",
        "mapion.co.jp",
        "navitime.co.jp",
        "navitime.com",
        "parkinggod.jp",
        "times-info.net",
    ]

    static let excludedDomainsHashValue = excludedDomains.reduce(0, { (hashValue, domain) in hashValue ^ domain.hashValue })

    // 10MB, 7 days
    public static let cache = Cache(name: "OfficialParkingSearch", byteLimit: 10 * 1024 * 1024, ageLimit: 60 * 60 * 24 * 7)

    public let destination: MKMapItem

    public let webView: WKWebView

    public private (set) var state: State = .idle {
        didSet {
            if state != oldValue {
                delegate?.officialParkingSearch(self, didChange: state)
            }
        }
    }

    public weak var delegate: OfficialParkingSearchDelegate?

    private let geocoder = CLGeocoder()

    private var location: CLLocation {
        let coordinate = destination.placemark.coordinate
        return CLLocation(latitude: coordinate.latitude, longitude: coordinate.longitude)
    }

    private var currentPageType: PageType?

    enum PageType {
        case googleSearchForm
        case googleSearchResult
        case googleRedirectionWarning
        case googleBotSuspicion
        case googleUnknown
        case other
    }

    private let hostnameParser = try! TLDExtract(useFrozenData: true)

    private var address: CLPlacemark?

    private lazy var cacheKey: String = {
        let coordinate = destination.placemark.coordinate
        let key = String(format: "%@|%f,%f|%d", destination.name!, coordinate.latitude, coordinate.longitude, Self.excludedDomainsHashValue)
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

    public init(destination: MKMapItem, webView: WKWebView) throws {
        if destination.name == nil || destination.name?.isEmpty == true {
            throw OfficialParkingSearchError.destinationMustHaveName
        }

        self.destination = destination
        self.webView = webView

        super.init()

        webView.navigationDelegate = self
    }

    deinit {
        stop()
    }

    public func start() {
        state = .searching

        if let cachedURL = cachedURL {
            webView.load(URLRequest(url: cachedURL))
        } else {
            performSearch()
        }
    }

    public func stop() {
        webView.stopLoading()
        geocoder.cancelGeocode()
    }

    private func performSearch() {
        startLoadingGoogleSearchFormPage()

        fetchAddress { (result) in
            switch result {
            case .success(let placemark):
                self.address = placemark

                if self.currentPageType == .googleSearchForm {
                    self.performImFeelingLucky(address: placemark)
                }
            case .failure(let error):
                logger.error(error)
            }
        }
    }

    private func startLoadingGoogleSearchFormPage() {
        let url = URL(string: "https://www.google.com/")!
        webView.load(URLRequest(url: url))
    }

    private func fetchAddress(completion: @escaping (Result<CLPlacemark, Error>) -> Void) {
        let locale = Locale(identifier: "ja_JP")

        geocoder.reverseGeocodeLocation(location, preferredLocale: locale) { (placemarks, error) in
            if let error = error {
                completion(.failure(error))
                return
            }

            if let placemark = placemarks?.first {
                completion(.success(placemark))
            }
        }
    }

    private func pageType(of url: URL) -> PageType? {
        guard let host = hostnameParser.parse(url) else { return nil }

        if host.secondLevelDomain == "google" {
            if url.path == "/" {
                return .googleSearchForm
            } else if url.path == "/search" {
                return .googleSearchResult
            } else if url.path == "/url" {
                return .googleRedirectionWarning
            } else if url.path == "/sorry/index" {
                return .googleBotSuspicion
            } else {
                return .googleUnknown
            }
        } else {
            return .other
        }
    }

    private func performImFeelingLucky(address: CLPlacemark) {
        // We manipulate Google search form page with JS here
        // rather than request with URL built by ourselves
        // because `iflsig` parameter which is a sort of CRSF guard
        // is needed for I'm Feeling Lucky to work properly.
        // https://superuser.com/a/1496084

        let script = """
            document.getElementsByName('q')[0].value = query;

            setTimeout(() => {
                let imFeelingLuckyElement = document.getElementsByName('btnI')[0];

                // Mobile search form page doesn't have I'm Feeling Lucky button
                if (!imFeelingLuckyElement) {
                    imFeelingLuckyElement = document.createElement('input');
                    imFeelingLuckyElement.name = 'btnI';
                    imFeelingLuckyElement.value = "I'm Feeling Lucky";
                    imFeelingLuckyElement.type = 'submit';

                    const formElement = document.getElementsByTagName('form')[0];
                    formElement.insertBefore(imFeelingLuckyElement, null);
                }

                imFeelingLuckyElement.click();
            }, 500);
        """

        var queryComponents = [
            destination.name,
            address.administrativeArea,
            address.locality,
            "\"駐車場\"",
        ].compactMap { $0 }

        queryComponents.append(contentsOf: Self.excludedDomains.map { "-site:\($0)" })

        let query = queryComponents.joined(separator: " ")

        logger.debug(query)

        webView.callAsyncJavaScript(
            script,
            arguments: ["query": query],
            in: nil,
            in: .defaultClient)
        { (result) in
            switch result {
            case .success:
                break
            case .failure(let error):
                logger.error(error)
            }
        }
    }

    private func forceRedirection() -> Bool {
        guard let url = webView.url else { return false }
        let queryItems = URLComponents(url: url, resolvingAgainstBaseURL: false)?.queryItems
        guard let destinationURLString = queryItems?.first(where: { $0.name == "q" })?.value else { return false }
        guard let destinationURL = URL(string: destinationURLString) else { return false }

        webView.load(URLRequest(url: destinationURL))

        return true
    }

    private func tryExtractingParkingDescription(completion: @escaping (Result<String?, Error>) -> Void) {
        let function = """
            (element) => {
                if (!element) {
                    return null;
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
                    return null;
                }

                const descriptionElement = labelElement.nextElementSibling;
                return descriptionElement?.innerText.trim() || descriptionElement?.textContent.trim();
            }
        """

        evaluateJavaScriptWithElementDescribingParking(function) { (result) in
            switch result {
            case .success(let value as String):
                completion(.success(value))
            case .success:
                completion(.success(nil))
            case .failure(let error):
                completion(.failure(error))
            }
        }
    }

    public func evaluateJavaScriptWithElementDescribingParking(_ javaScriptFunction: String, completion: @escaping (Result<Any, Error>) -> Void) {
        findBestElement(describing: "駐車場", andEvaluate: javaScriptFunction, completion: completion)
    }

    private func findBestElement(describing text: String, andEvaluate javaScriptFunction: String, completion: @escaping (Result<Any, Error>) -> Void) {
        let script = """
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

        webView.callAsyncJavaScript(
            script,
            arguments: ["searchText": text, "callbackSnippet": javaScriptFunction as Any],
            in: nil,
            in: .defaultClient,
            completionHandler: completion
        )
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

    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        currentPageType = pageType(of: url)

        logger.debug("\(url) (\(String(describing: currentPageType))")

        switch currentPageType {
        case .googleSearchForm:
            if let address = address {
                performImFeelingLucky(address: address)
            }
        case .googleRedirectionWarning:
            if !forceRedirection() {
                state = .notFound
            }
        case .googleSearchResult, .googleUnknown:
            state = .notFound
        case .googleBotSuspicion:
            state = .actionRequired
        case .other:
            cachedURL = url

            tryExtractingParkingDescription { (result) in
                let parkingInformation: ParkingInformation

                switch result {
                case .success(let description):
                    logger.debug("Extracted parking description: \(String(describing: description))")
                    parkingInformation = ParkingInformation(url: url, description: description)
                case .failure(let error):
                    logger.error(error)
                    parkingInformation = ParkingInformation(url: url)
                }

                self.state = .found(parkingInformation)
            }
        default:
            break
        }
    }
}

extension OfficialParkingSearch {
    public enum State: Equatable {
        case idle
        case searching
        case actionRequired
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
