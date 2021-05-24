//
//  WebViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/12/02.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import WebKit

class WebViewController: UIViewController {
    static var defaultUserAgent: String?

    lazy var webView: WKWebView = {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = [.address, .link, .phoneNumber]
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        return webView
    }()

    lazy var doneBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

    lazy var backwardBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(goBackward))
    lazy var forwardBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), style: .plain, target: self, action: #selector(goForward))
    lazy var reloadOrStopLoadingBarButtonItem = UIBarButtonItem()
    lazy var openInSafariBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "safari"), style: .plain, target: self, action: #selector(openInSafari))

    let url: URL

    var keyValueObservations: [NSKeyValueObservation] = []

    init(url: URL) {
        self.url = url
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.rightBarButtonItem = doneBarButtonItem

        configureToolBarButtonItems()

        configureWebView { [weak self] in
            self?.startLoadingPage()
        }
    }

    func configureToolBarButtonItems() {
        toolbarItems = [
            backwardBarButtonItem,
            .flexibleSpace(),
            forwardBarButtonItem,
            .flexibleSpace(),
            reloadOrStopLoadingBarButtonItem,
            .flexibleSpace(),
            openInSafariBarButtonItem
        ]

        keyValueObservations.append(webView.observe(\.title, changeHandler: { [unowned self] (webView, change) in
            navigationItem.title = webView.title
        }))

        keyValueObservations.append(webView.observe(\.isLoading, options: .initial, changeHandler: { [unowned self] (webView, change) in
            updateReloadOrStopLoadingBarButtonItem()
        }))

        keyValueObservations.append(webView.observe(\.canGoBack, options: .initial, changeHandler: { [unowned self] (webView, change) in
            backwardBarButtonItem.isEnabled = webView.canGoBack
        }))

        keyValueObservations.append(webView.observe(\.canGoForward, options: .initial, changeHandler: { [unowned self] (webView, change) in
            forwardBarButtonItem.isEnabled = webView.canGoForward
        }))

        keyValueObservations.append(webView.observe(\.url, options: .initial, changeHandler: { [unowned self] (webView, change) in
            openInSafariBarButtonItem.isEnabled = webView.url != nil
        }))
    }

    func configureWebView(completion: @escaping () -> Void) {
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.safeAreaLayoutGuide.leadingAnchor),
            view.safeAreaLayoutGuide.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
            view.safeAreaLayoutGuide.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ])

        guard traitCollection.horizontalSizeClass == .compact else {
            completion()
            return
        }

        let webPagePreferences = WKWebpagePreferences()
        webPagePreferences.preferredContentMode = .mobile
        webView.configuration.defaultWebpagePreferences = webPagePreferences

        getDefaultUserAgent { (defaultUserAgent) in
            if let defaultUserAgent = defaultUserAgent {
                // Some sites like Tabelog checks whether user agent includes "iPhone" or not to determine whether the device is mobile one
                self.webView.customUserAgent = defaultUserAgent.replacingOccurrences(of: "iPad", with: "iPhone")
            }

            completion()
        }
    }

    func getDefaultUserAgent(completion: @escaping (String?) -> Void) {
        if let userAgent = WebViewController.defaultUserAgent {
            completion(userAgent)
            return
        }

        webView.evaluateJavaScript("navigator.userAgent", completionHandler: { (userAgent, error) in
            WebViewController.defaultUserAgent = userAgent as? String
            completion(WebViewController.defaultUserAgent)
        })
    }

    func startLoadingPage() {
        webView.load(URLRequest(url: url))
    }

    func updateReloadOrStopLoadingBarButtonItem() {
        let symbolConfiguration = UIImage.SymbolConfiguration(scale: .default)

        if webView.isLoading {
            reloadOrStopLoadingBarButtonItem.image = UIImage(systemName: "xmark", withConfiguration: symbolConfiguration)
            reloadOrStopLoadingBarButtonItem.action = #selector(stopLoading)
        } else {
            reloadOrStopLoadingBarButtonItem.image = UIImage(systemName: "arrow.clockwise", withConfiguration: symbolConfiguration)
            reloadOrStopLoadingBarButtonItem.action = #selector(reload)
        }
    }

    @objc func done() {
        dismiss(animated: true)
    }

    @objc func goBackward() {
        webView.goBack()
    }

    @objc func goForward() {
        webView.goForward()
    }

    @objc func reload() {
        webView.reload()
    }

    @objc func stopLoading() {
        webView.stopLoading()
    }

    @objc func openInSafari() {
        guard let url = webView.url, let application = sharedApplication else { return }
        application.perform(sel_registerName("openURL:"), with: url)
    }

    // We cannot use UIApplication.shared.open(_:options:completionHandler:) in app extensions
    // https://stackoverflow.com/a/44499289/784241
    var sharedApplication: UIApplication? {
        var responder: UIResponder? = self

        while responder != nil {
           if let application = responder as? UIApplication {
               return application
           }

            responder = responder?.next
       }

        return nil
    }
}
