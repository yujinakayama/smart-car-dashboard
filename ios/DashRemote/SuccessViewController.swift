//
//  SuccessViewController.swift
//  DashRemote
//
//  Created by Yuji Nakayama on 2020/02/08.
//  Copyright © 2020 Yuji Nakayama. All rights reserved.
//

import UIKit

class SuccessViewController: UIViewController {
    @IBOutlet weak var checkmarkView: SuccessCheckmarkView!

    let feedbackGenerator = UINotificationFeedbackGenerator()

    override func viewDidLoad() {
        super.viewDidLoad()

        feedbackGenerator.prepare()
    }

    override func viewDidAppear(_ animated: Bool) {
        super.viewDidAppear(animated)

        checkmarkView.startAnimating()

        feedbackGenerator.notificationOccurred(.success)

        DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
            self.dismiss(animated: true)
        }
    }
}
