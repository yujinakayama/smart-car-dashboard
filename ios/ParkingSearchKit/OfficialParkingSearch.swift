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
    ]

    static let cache = Cache(name: "OfficialParkingSearch", ageLimit: 60 * 60 * 24 * 30) // 30 days

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
        let key = String(format: "%@|%f,%f", destination.name!, coordinate.latitude, coordinate.longitude)
        return Cache.digestString(of: key)
    }()

    private var cachedURL: URL? {
        get {
            return Self.cache.object(forKey: cacheKey) as? URL
        }

        set {
            Self.cache.setObjectAsync(newValue as Any, forKey: cacheKey)
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
                print(error)
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
            address.subAdministrativeArea,
            address.locality,
            "\"駐車場\"",
        ].compactMap { $0 }

        queryComponents.append(contentsOf: Self.excludedDomains.map { "-site:\($0)" })

        let query = queryComponents.joined(separator: " ")

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
                print(error)
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
}

extension OfficialParkingSearch: WKNavigationDelegate {
    public func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
        guard let url = webView.url else { return }

        print(#function, url)

        currentPageType = pageType(of: url)

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
            state = .found
        case nil:
            break
        }
    }
}

extension OfficialParkingSearch {
    public enum State: Equatable {
        case idle
        case searching
        case actionRequired
        case found
        case notFound
    }
}

enum OfficialParkingSearchError: Error {
    case destinationMustHaveName
}
