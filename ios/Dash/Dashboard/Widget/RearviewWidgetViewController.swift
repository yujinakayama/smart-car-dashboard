//
//  RearviewWidgetViewController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/11/21.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import RearviewKit

class RearviewWidgetViewController: UIViewController {
    var rearviewViewController: RearviewViewController?

    var isVisible = false

    lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(gestureRecognizerDidRecognizeDoubleTap))
        gestureRecognizer.numberOfTapsRequired = 2
        return gestureRecognizer
    }()

    var warningLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(applicationDidEnterBackground), name: UIApplication.didEnterBackgroundNotification, object: nil)

        setUpRearviewViewControllerIfPossible()
    }

    func setUpRearviewViewControllerIfPossible() {
        if let configuration = RearviewDefaults.shared.configuration {
            setUpRearviewViewController(configuration: configuration)
        } else {
            warnAboutInvalidRaspberryPiAddress()
        }
    }

    func setUpRearviewViewController(configuration: RearviewConfiguration) {
        let rearviewViewController = RearviewViewController(configuration: configuration, cameraSensitivityMode: RearviewDefaults.shared.cameraSensitivityMode)
        rearviewViewController.delegate = self
        rearviewViewController.contentMode = .top

        addChild(rearviewViewController)
        rearviewViewController.view.frame = view.bounds
        view.addSubview(rearviewViewController.view)
        rearviewViewController.didMove(toParent: self)

        rearviewViewController.view.addGestureRecognizer(doubleTapGestureRecognizer)
        rearviewViewController.tapGestureRecognizer.require(toFail: doubleTapGestureRecognizer)

        self.rearviewViewController = rearviewViewController
    }

    func warnAboutInvalidRaspberryPiAddress() {
        let label = UILabel()
        label.text = "You need to specity your Raspberry Pi address in the Settings app."
        label.textColor = UIColor(white: 1, alpha: 0.5)
        label.numberOfLines = 0
        label.textAlignment = .center

        view.addSubview(label)

        label.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            label.centerXAnchor.constraint(equalTo: view.centerXAnchor),
            label.centerYAnchor.constraint(equalTo: view.centerYAnchor),
            label.widthAnchor.constraint(equalTo: view.widthAnchor, multiplier: 0.8)
        ])

        warningLabel = label
    }

    func tearDownRearviewViewControllerIfNeeded() {
        guard let rearviewViewController = rearviewViewController else { return }

        rearviewViewController.stop()

        rearviewViewController.willMove(toParent: nil)
        rearviewViewController.view.removeFromSuperview()
        rearviewViewController.removeFromParent()

        self.rearviewViewController = nil
    }

    override func traitCollectionDidChange(_ previousTraitCollection: UITraitCollection?) {
        super.traitCollectionDidChange(previousTraitCollection)

        guard let rearviewViewController = rearviewViewController else { return }

        if traitCollection.horizontalSizeClass == .compact {
            rearviewViewController.sensitivityModeControlPosition = .center
        } else {
            rearviewViewController.sensitivityModeControlPosition = .bottom
        }
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
        rearviewViewController?.start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        rearviewViewController?.stop()
    }

    @objc func applicationWillEnterForeground() {
        setUpRearviewViewControllerIfPossible()

        if isVisible {
            rearviewViewController?.start()
        }
    }

    @objc func applicationDidEnterBackground() {
        tearDownRearviewViewControllerIfNeeded()

        warningLabel?.removeFromSuperview()
        warningLabel = nil
    }

    @objc func gestureRecognizerDidRecognizeDoubleTap() {
        handOffToRearviewApp()
    }

    func handOffToRearviewApp() {
        rearviewViewController?.stop()

        var urlComponents = URLComponents()
        urlComponents.scheme = "rearview"
        urlComponents.host = "handoff"
        let url = urlComponents.url!
        UIApplication.shared.open(url, options: [:])
    }
}

extension RearviewWidgetViewController: RearviewViewControllerDelegate {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode) {
        RearviewDefaults.shared.cameraSensitivityMode = cameraSensitivityMode
    }
}
