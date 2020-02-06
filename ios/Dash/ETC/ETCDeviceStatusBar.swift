//
//  ETCDeviceStatusBar.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/19.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCDeviceStatusBar {
    let device: ETCDevice

    lazy var items = [
        UIBarButtonItem(customView: connectionStatusImageView),
        UIBarButtonItem(customView: cardStatusImageView)
    ]

    private var connectionStatusImageView: UIImageView = {
        let view = UIImageView()
        view.contentMode = .scaleAspectFit
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        return view
    }()

    private var cardStatusImageView: UIImageView = {
        let view = UIImageView()
        view.image = UIImage(systemName: "creditcard.fill")
        view.contentMode = .scaleAspectFit
        view.heightAnchor.constraint(equalToConstant: 24).isActive = true
        view.widthAnchor.constraint(equalTo: view.heightAnchor).isActive = true
        return view
    }()

    init(device: ETCDevice) {
        self.device = device
        updateConnectionStatusView()
        updateCardStatusView()
        startObservingNotifications()
    }

    private func startObservingNotifications() {
        let notificationCenter = NotificationCenter.default

        notificationCenter.addObserver(forName: .ETCDeviceDidConnect, object: device, queue: .main) { (notification) in
            self.updateConnectionStatusView()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDisconnect, object: device, queue: .main) { (notification) in
            self.updateConnectionStatusView()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDetectCardInsertion, object: device, queue: .main) { (notification) in
            self.updateCardStatusView()
        }

        notificationCenter.addObserver(forName: .ETCDeviceDidDetectCardEjection, object: device, queue: .main) { (notification) in
            self.updateCardStatusView()
        }
    }

    private func updateConnectionStatusView() {
        if device.isConnected {
            connectionStatusImageView.image = UIImage(systemName: "bolt.fill")
            connectionStatusImageView.tintColor = UIColor.label
        } else {
            connectionStatusImageView.image = UIImage(systemName: "bolt.slash.fill")
            connectionStatusImageView.tintColor = UIColor(named: "Inactive Bar Item Color")
        }
    }

    private func updateCardStatusView() {
        if device.currentCard != nil {
            cardStatusImageView.tintColor = UIColor.label
        } else {
            cardStatusImageView.tintColor = UIColor(named: "Inactive Bar Item Color")
        }
    }

}
