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

    var isVisible = false

    override func viewDidLoad() {
        super.viewDidLoad()
        setUpRearviewViewController()
        setUpStatusBarView()
    }

    func setUpRearviewViewController() {
        let configuration = RearviewConfiguration(raspberryPiAddress: "192.168.100.1", digitalGainForLowLightMode: 8, digitalGainForUltraLowLightMode: 16)
        let rearviewViewController = RearviewViewController(configuration: configuration)
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
        rearviewViewController.start()
    }
}
