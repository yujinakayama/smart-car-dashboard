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

    var justHandedOffFromOtherApp: Bool {
        get {
            if let lastHandOffTimeFromOtherApp = lastHandOffTimeFromOtherApp {
                return Date().timeIntervalSince(lastHandOffTimeFromOtherApp) < 1
            } else {
                return false
            }
        }

        set {
            if newValue {
                lastHandOffTimeFromOtherApp = Date()
            } else {
                lastHandOffTimeFromOtherApp = nil
            }
        }
    }

    private var lastHandOffTimeFromOtherApp: Date?

    lazy var doubleTapGestureRecognizer: UITapGestureRecognizer = {
        let gestureRecognizer = UITapGestureRecognizer(target: self, action: #selector(gestureRecognizerDidRecognizeDoubleTap))
        gestureRecognizer.numberOfTapsRequired = 2
        return gestureRecognizer
    }()

    var warningLabel: UILabel?

    override func viewDidLoad() {
        super.viewDidLoad()

        overrideUserInterfaceStyle = .dark
        view.backgroundColor = .black

        NotificationCenter.default.addObserver(self, selector: #selector(sceneWillEnterForeground), name: UIScene.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(self, selector: #selector(sceneDidEnterBackground), name: UIScene.didEnterBackgroundNotification, object: nil)

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
        guard rearviewViewController == nil else { return }

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

        stop()

        rearviewViewController.willMove(toParent: nil)
        rearviewViewController.view.removeFromSuperview()
        rearviewViewController.removeFromParent()

        self.rearviewViewController = nil
    }

    func start() {
        if justHandedOffFromOtherApp {
            justHandedOffFromOtherApp = false

            Timer.scheduledTimer(withTimeInterval: 0.5, repeats: false) { [weak self] (timer) in
                self?.rearviewViewController?.start()
            }
        } else {
            rearviewViewController?.start()
        }
    }

    func stop() {
        rearviewViewController?.stop()
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
        start()
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
        stop()
    }

    @objc func sceneWillEnterForeground() {
        setUpRearviewViewControllerIfPossible()

        if isVisible {
            start()
        }
    }

    @objc func sceneDidEnterBackground() {
        tearDownRearviewViewControllerIfNeeded()

        warningLabel?.removeFromSuperview()
        warningLabel = nil
    }

    @objc func gestureRecognizerDidRecognizeDoubleTap() {
        handOffToRearviewApp()
    }

    func handOffToRearviewApp() {
        stop()

        var urlComponents = URLComponents()
        urlComponents.scheme = "rearview"
        urlComponents.host = "handoff"

        UIApplication.shared.open(urlComponents.url!, options: [:])
    }
}

extension RearviewWidgetViewController: RearviewViewControllerDelegate {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode) {
        RearviewDefaults.shared.cameraSensitivityMode = cameraSensitivityMode
    }
}
