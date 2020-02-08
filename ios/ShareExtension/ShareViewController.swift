//
//  ShareViewController.swift
//  ShareExtension
//
//  Created by Yuji Nakayama on 2020/01/28.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit
import DashShareKit
import SVProgressHUD

enum ShareError: Error {
    case serverError
    case unknown
}

class ShareViewController: UIViewController {
    override func viewDidLoad() {
        super.viewDidLoad()

        SVProgressHUD.setViewForExtension(view)
        SVProgressHUD.setMinimumSize(CGSize(width: 120, height: 120))
        SVProgressHUD.setHapticsEnabled(true)

        share()
    }

    func share() {
        SVProgressHUD.show(withStatus: "Sending")

        sharingItem.share { (error) in
            if let error = error {
                self.cancelRequest(withError: error)
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
        SVProgressHUD.showSuccess(withStatus: "Sent")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extensionContext!.completeRequest(returningItems: nil)
        }
    }

    func cancelRequest(withError error: Error) {
        SVProgressHUD.showError(withStatus: "Failed")

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.extensionContext!.cancelRequest(withError: error)
        }
    }
}