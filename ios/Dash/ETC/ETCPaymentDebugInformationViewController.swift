//
//  ETCPaymentDebugInformationController.swift
//  Dash
//
//  Created by Yuji Nakayama on 2020/01/13.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class ETCPaymentDebugInformationViewController: UIViewController {
    @IBOutlet weak var textView: UITextView!

    var payment: ETCPaymentProtocol?

    override func viewDidLoad() {
        if let payment = payment {
            textView.text = String(reflecting: payment)
        } else {
            textView.text = ""
        }
    }
}

