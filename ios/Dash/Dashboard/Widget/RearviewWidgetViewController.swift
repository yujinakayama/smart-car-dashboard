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

    lazy var statusBarView: UIView = {
        let effect = UIBlurEffect(style: .regular)
        let statusBarView = UIVisualEffectView(effect: effect)
        return statusBarView
    }()

    var configuration: RearviewConfiguration {
        return RearviewConfiguration(
            raspberryPiAddress: RearviewDefaults.shared.raspberryPiAddress,
            digitalGainForLowLightMode: RearviewDefaults.shared.digitalGainForLowLightMode,
            digitalGainForUltraLowLightMode: RearviewDefaults.shared.digitalGainForUltraLowLightMode
        )
    }

    var isVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpRearviewViewController()
        setUpStatusBarView()
    }

    func setUpRearviewViewController() {
        let rearviewViewController = RearviewViewController(configuration: configuration, cameraSensitivityMode: RearviewDefaults.shared.cameraSensitivityMode)
        rearviewViewController.delegate = self
        rearviewViewController.videoGravity = .resizeAspectFill

        addChild(rearviewViewController)
        rearviewViewController.view.frame = view.bounds
        view.addSubview(rearviewViewController.view)
        rearviewViewController.didMove(toParent: self)

        self.rearviewViewController = rearviewViewController

        NotificationCenter.default.addObserver(self, selector: #selector(applicationWillEnterForeground), name: UIApplication.willEnterForegroundNotification, object: nil)

        NotificationCenter.default.addObserver(rearviewViewController, selector: #selector(RearviewViewController.stop), name: UIApplication.didEnterBackgroundNotification, object: nil)
    }

    func setUpStatusBarView() {
        view.addSubview(statusBarView)

        statusBarView.translatesAutoresizingMaskIntoConstraints = false

        NSLayoutConstraint.activate([
            statusBarView.topAnchor.constraint(equalTo: view.topAnchor),
            statusBarView.leftAnchor.constraint(equalTo: view.leftAnchor),
            statusBarView.rightAnchor.constraint(equalTo: view.rightAnchor),
            statusBarView.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
        ])
    }

    override func viewWillAppear(_ animated: Bool) {
        super.viewWillAppear(animated)
        isVisible = true
    }

    override func viewDidDisappear(_ animated: Bool) {
        super.viewDidDisappear(animated)
        isVisible = false
    }

    @objc func applicationWillEnterForeground() {
        guard isVisible, let rearviewViewController = rearviewViewController else { return }

        rearviewViewController.configuration = configuration
        rearviewViewController.cameraSensitivityMode = RearviewDefaults.shared.cameraSensitivityMode
        rearviewViewController.start()
    }
}

extension RearviewWidgetViewController: RearviewViewControllerDelegate {
    func rearviewViewController(didChangeCameraSensitivityMode cameraSensitivityMode: CameraSensitivityMode) {
        RearviewDefaults.shared.cameraSensitivityMode = cameraSensitivityMode
    }
}
