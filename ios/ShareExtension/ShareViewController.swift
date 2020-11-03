//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import DashShareKit
import JGProgressHUD

enum ShareError: Error {
    case pairingRequired
    case serverError
    case unknown
}

class ShareViewController: UIViewController {
    let hud = JGProgressHUD()

    override func viewDidLoad() {
        super.viewDidLoad()

        hud.square = true

        share()
    }

    func share() {
        guard let vehicleID = PairedVehicle.defaultVehicleID else {
            self.cancelRequest(withError: ShareError.pairingRequired, message: "Pairing Required")
            return
        }

        hud.textLabel.text = "Sending"
        hud.show(in: view)

        sharingItem.share(with: vehicleID) { (error) in
            if let error = error {
                self.cancelRequest(withError: error, message: "Failed")
            } else {
                self.completeRequest()
            }
        }
    }

    lazy var sharingItem: SharingItem = {
        let extensionItems = self.extensionContext!.inputItems as! [NSExtensionItem]
        let encoder = SharingItem.ExtensionItemEncoder(extensionItem: extensionItems.first!)
        return SharingItem(encoder: encoder)
    }()

    func completeRequest() {
        hud.textLabel.text = "Sent"
        hud.indicatorView = JGProgressHUDSuccessIndicatorView()
        hud.show(in: view)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extensionContext!.completeRequest(returningItems: nil)
        }
    }

    func cancelRequest(withError error: Error, message: String) {
        hud.textLabel.text = message
        hud.indicatorView = JGProgressHUDErrorIndicatorView()
        hud.show(in: view)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extensionContext!.cancelRequest(withError: error)
        }
    }
}
