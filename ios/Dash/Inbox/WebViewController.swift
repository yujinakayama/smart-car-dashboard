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
    @IBOutlet weak var webView: WKWebView!

    @IBOutlet weak var doneBarButtonItem: UIBarButtonItem!

    @IBOutlet weak var backwardBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var forwardBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var openInSafariBarButtonItem: UIBarButtonItem!
    @IBOutlet weak var openDirectionsInMapsBarButtonItem: UIBarButtonItem!

    var item: SharedItemProtocol!

    var keyValueObservations: [NSKeyValueObservation] = []

    override func viewDidLoad() {
        super.viewDidLoad()

        navigationItem.title = item.title

        setUpBarButtonItems()

        webView.load(URLRequest(url: item.url))
    }

    func setUpBarButtonItems() {
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

        openDirectionsInMapsBarButtonItem.isEnabled = item is Location
    }

    func updateReloadOrStopLoadingBarButtonItem() {
        let symbolConfiguration = UIImage.SymbolConfiguration(scale: .default)

        if webView.isLoading {
            let image = UIImage(systemName: "xmark", withConfiguration: symbolConfiguration)
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(stopLoading))
        } else {
            let image = UIImage(systemName: "arrow.clockwise", withConfiguration: symbolConfiguration)
            navigationItem.rightBarButtonItem = UIBarButtonItem(image: image, style: .plain, target: self, action: #selector(reload))
        }
    }

    @IBAction func reload() {
        webView.reload()
    }

    @IBAction func stopLoading() {
        webView.stopLoading()
    }

    @IBAction func done() {
        dismiss(animated: true)
    }

    @IBAction func goBackward() {
        webView.goBack()
    }

    @IBAction func goForward() {
        webView.goForward()
    }

    @IBAction func openInSafari() {
        guard let url = webView.url else { return }
        UIApplication.shared.open(url, options: [:])
    }

    @IBAction func openDirectionsInMaps() {
        guard let location = item as? Location else { return }
        location.open(from: nil)
    }
}
