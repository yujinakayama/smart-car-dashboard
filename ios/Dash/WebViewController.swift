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
    // https://stackoverflow.com/a/65825682/784241
    static let defaultUserAgent: String = WKWebView().value(forKey: "userAgent") as! String

    static let mobileUserAgent = defaultUserAgent
        .replacingOccurrences(of: "iPad|Macintosh", with: "iPhone", options: .regularExpression)

    static let desktopUserAgent = defaultUserAgent
        .replacingOccurrences(of: "iPhone|iPad", with: "Macintosh", options: .regularExpression)
        .replacingOccurrences(of: " Mobile/\\S+", with: "", options: .regularExpression)

    static func makeWebView() -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.dataDetectorTypes = [.address, .link, .phoneNumber]
        configuration.ignoresViewportScaleLimits = true
        configuration.mediaTypesRequiringUserActionForPlayback = .all

        // Fix the content mode to the mobile one since this cannot be dynamically changed
        // after creating WKWebView instance.
        // Instead, we dynamically modify user agent by ourselves.
        configuration.defaultWebpagePreferences.preferredContentMode = .mobile

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.allowsBackForwardNavigationGestures = true
        webView.backgroundColor = .secondarySystemBackground
        return webView
    }

    static func userAgent(for contentMode: ContentMode) -> String {
        switch contentMode {
        case .mobile:
            return Self.mobileUserAgent
        case .desktop:
            return Self.desktopUserAgent
        }
    }

    let webView: WKWebView

    let progressView: UIProgressView = {
        let progressView = UIProgressView()
        progressView.progressViewStyle = .bar
        return progressView
    }()

    var preferredContentMode: PreferredContentMode {
        didSet {
            applyContentMode()
        }
    }

    private var pendingURL: URL?

    lazy var doneBarButtonItem = UIBarButtonItem(barButtonSystemItem: .done, target: self, action: #selector(done))

    lazy var backwardBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.backward"), style: .plain, target: self, action: #selector(goBackward))
    lazy var forwardBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "chevron.forward"), style: .plain, target: self, action: #selector(goForward))
    lazy var reloadOrStopLoadingBarButtonItem = UIBarButtonItem()
    lazy var openInSafariBarButtonItem = UIBarButtonItem(image: UIImage(systemName: "safari"), style: .plain, target: self, action: #selector(openInSafari))

    var keyValueObservations: [NSKeyValueObservation] = []

    init(webView: WKWebView? = nil, contentMode: PreferredContentMode = .auto) {
        self.webView = webView ?? Self.makeWebView()
        self.preferredContentMode = contentMode
        super.init(nibName: nil, bundle: nil)
        configureToolBarButtonItems()
    }

    required init?(coder: NSCoder) {
        fatalError("init(coder:) has not been implemented")
    }

    func loadPage(url: URL) {
        if isViewLoaded {
            webView.load(URLRequest(url: url))
        } else {
            pendingURL = url
        }
    }

    override func viewDidLoad() {
        super.viewDidLoad()

        // https://developer.apple.com/forums/thread/682420
        navigationItem.scrollEdgeAppearance = navigationController?.navigationBar.standardAppearance

        if let toolbar = navigationController?.toolbar {
            toolbar.scrollEdgeAppearance = toolbar.standardAppearance
        }

        navigationItem.rightBarButtonItem = doneBarButtonItem

        addWebView()

        addProgressView()

        applyContentMode()

        if let pendingURL = pendingURL {
            webView.load(URLRequest(url: pendingURL))
            self.pendingURL = nil
        }
    }

    private func configureToolBarButtonItems() {
        toolbarItems = [
            backwardBarButtonItem,
            .flexibleSpace(),
            forwardBarButtonItem,
            .flexibleSpace(),
            reloadOrStopLoadingBarButtonItem,
            .flexibleSpace(),
            openInSafariBarButtonItem
        ]

        keyValueObservations.append(webView.observe(\.title, options: .initial, changeHandler: { [unowned self] (webView, change) in
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

    private func addWebView() {
        view.addSubview(webView)

        webView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            webView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            view.trailingAnchor.constraint(equalTo: webView.trailingAnchor),
            webView.topAnchor.constraint(equalTo: view.topAnchor),
            view.bottomAnchor.constraint(equalTo: webView.bottomAnchor),
        ])

        webView.isHidden = false
    }

    private func addProgressView() {
        guard let navigationBar = navigationController?.navigationBar else { return }

        navigationBar.addSubview(progressView)

        progressView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            progressView.leftAnchor.constraint(equalTo: navigationBar.leftAnchor),
            progressView.rightAnchor.constraint(equalTo: navigationBar.rightAnchor),
            progressView.bottomAnchor.constraint(equalTo: navigationBar.bottomAnchor, constant: -1),
            progressView.heightAnchor.constraint(equalToConstant: 2)
        ])

        keyValueObservations.append(webView.observe(\.estimatedProgress, options: [.initial, .old], changeHandler: { [unowned self] (webView, change) in
            let progress = webView.estimatedProgress
            let completed = progress == 1
            let increasing = progress > (change.oldValue ?? 0)

            if !completed {
                self.progressView.alpha = 1
            }

            if increasing {
                let animationDuration = completed ? 0.1 : 0.25

                UIView.animate(withDuration: animationDuration, delay: 0, options: .beginFromCurrentState) {
                    self.progressView.progress = Float(progress)
                    self.progressView.layoutIfNeeded()
                } completion: { (finished) in
                    if completed {
                        UIView.animate(withDuration: 0.5, delay: 0, options: [.curveEaseIn]) {
                            self.progressView.alpha = 0
                        } completion: { (finished) in
                            self.progressView.progress = 0
                        }
                    }
                }
            } else {
                self.progressView.progress = Float(progress)
            }
        }))
    }

    private func applyContentMode() {
        switch preferredContentMode {
        case .auto:
            if view.bounds.width < 700 {
                webView.customUserAgent = Self.userAgent(for: .mobile)
            } else {
                webView.customUserAgent = Self.userAgent(for: .desktop)
            }
        case .mobile:
            webView.customUserAgent = Self.userAgent(for: .mobile)
        case .desktop:
            webView.customUserAgent = Self.userAgent(for: .desktop)
        }
    }

    override func viewDidLayoutSubviews() {
        super.viewDidLayoutSubviews()

        if preferredContentMode == .auto {
            applyContentMode()
        }
    }

    private func updateReloadOrStopLoadingBarButtonItem() {
        let symbolConfiguration = UIImage.SymbolConfiguration(scale: .default)

        reloadOrStopLoadingBarButtonItem.target = self

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
        guard let url = webView.url else { return }
        UIApplication.shared.open(url)
    }
}

extension WebViewController {
    enum PreferredContentMode {
        case auto
        case mobile
        case desktop
    }

    enum ContentMode {
        case mobile
        case desktop
    }
}
