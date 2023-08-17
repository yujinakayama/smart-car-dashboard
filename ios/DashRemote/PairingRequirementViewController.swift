//
//  PairingRequirementViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/10/31.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class PairingRequirementViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        NotificationCenter.default.addObserver(forName: .PairedVehicleDidChangeDefaultVehicleID, object: nil, queue: nil) { [weak self] (notification) in
            if PairedVehicle.defaultVehicleID != nil {
                self?.showPairingCompletionAlert()
            }
        }
    }

    func showPairingCompletionAlert() {
        let alertController = UIAlertController(
            title: nil,
            message: "Pairing completed.",
            preferredStyle: .alert
        )

        alertController.addAction(UIAlertAction(title: "OK", style: .default, handler: { [weak self] _ in
            self?.dismiss(animated: true)
        }))

        present(alertController, animated: true)
    }
}
